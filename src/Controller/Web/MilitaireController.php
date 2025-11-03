<?php

namespace App\Controller\Web;

use App\Entity\Permission;
use App\Entity\Programme;
use App\Repository\ProgrammeRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/militaire', name: 'app_militaire_')]
#[IsGranted('ROLE_MILITAIRE')]
final class MilitaireController extends AbstractController
{
    public function __construct(private readonly EntityManagerInterface $em) {}

    #[Route('/demande', name: 'demande', methods: ['GET','POST'])]
    public function demandePermission(Request $request): Response
    {
        if ($request->isMethod('POST')) {
            $type   = trim((string) $request->request->get('type', ''));
            $motif  = trim((string) $request->request->get('motif', ''));
            $dDebut = (string) $request->request->get('date_debut', '');
            $dFin   = (string) $request->request->get('date_fin', '');

            $typesAutorises = ['courte', 'longue', 'étranger'];
            if (!\in_array($type, $typesAutorises, true)) {
                $this->addFlash('danger', 'Type de permission invalide.');
                return $this->redirectToRoute('app_militaire_demande');
            }

            $dateDebut = $this->parseDateFlexible($dDebut);
            $dateFin   = $this->parseDateFlexible($dFin);

            if (!$dateDebut || !$dateFin) {
                $this->addFlash('danger', 'Format de date invalide (utilise JJ/MM/AAAA ou AAAA-MM-JJ).');
                return $this->redirectToRoute('app_militaire_demande');
            }
            if ($dateFin < $dateDebut) {
                $this->addFlash('danger', 'La date de fin ne peut pas être antérieure à la date de début.');
                return $this->redirectToRoute('app_militaire_demande');
            }

            $dateDebutDT = $dateDebut instanceof \DateTime ? $dateDebut : \DateTime::createFromImmutable($dateDebut);
            $dateFinDT   = $dateFin   instanceof \DateTime ? $dateFin   : \DateTime::createFromImmutable($dateFin);

            $permission = (new Permission())
                ->setUser($this->getUser())
                ->setType($type)
                ->setMotif($motif)
                ->setDateDebut($dateDebutDT)
                ->setDateFin($dateFinDT)
                ->setStatut('en attente')
                ->setCreatedAt(new \DateTimeImmutable());

            $this->em->persist($permission);
            $this->em->flush();

            $this->addFlash('success', '✅ Votre demande a été enregistrée et sera traitée par votre officier.');
            return $this->redirectToRoute('app_militaire_dashboard');
        }

        return $this->render('militaire/demande.html.twig');
    }

    #[Route('/dashboard', name: 'dashboard', methods: ['GET'])]
    public function dashboard(ProgrammeRepository $progRepo): Response
    {
        $user = $this->getUser();
        if (!$user) {
            return $this->redirectToRoute('app_login');
        }

        // Permissions du militaire
        $permissions = $this->em->getRepository(Permission::class)
            ->findBy(['user' => $user], ['createdAt' => 'DESC']);

        $stats = ['total' => \count($permissions), 'acceptees' => 0, 'refusees' => 0, 'en_attente' => 0];
        foreach ($permissions as $p) {
            $s = strtolower($p->getStatut());
            if (str_contains($s, 'accept'))   $stats['acceptees']++;
            elseif (str_contains($s, 'refus')) $stats['refusees']++;
            else                                $stats['en_attente']++;
        }

        $solde = $this->calculerSoldePermissions($user);

        // Événements FullCalendar
        $calendarEvents = [];

        // 1) Permissions (vert)
        foreach ($permissions as $p) {
            $start   = $p->getDateDebut()?->format('Y-m-d');
            $endExcl = $p->getDateFin()?->modify('+1 day')->format('Y-m-d');
            if ($start && $endExcl) {
                $calendarEvents[] = [
                    'title' => 'Permission ' . $p->getType(),
                    'start' => $start,
                    'end'   => $endExcl,   // fin exclusive
                    'allDay'=> true,
                    'backgroundColor' => match (strtolower($p->getStatut())) {
                        'acceptée', 'acceptee' => '#198754',
                        'refusée',  'refusee'  => '#dc3545',
                        default                 => '#ffc107',
                    },
                    'borderColor' => '#ffffff',
                    'textColor'   => '#ffffff',
                ];
            }
        }

        // 2) Programmes de l’unité (bleu) — Programme.user = officier créateur
        $programmes = $progRepo->createQueryBuilder('p')
            ->leftJoin('p.user', 'o')
            ->andWhere('o.unite = :unite')
            ->setParameter('unite', $user->getUnite())
            ->getQuery()->getResult();

        foreach ($programmes as $pr) {
            $start   = $pr->getDateDebut()?->format('Y-m-d');
            $endExcl = $pr->getDateFin()?->modify('+1 day')->format('Y-m-d');

            $labelType = $pr->getType() === 'stage' ? 'Stage' : 'Mission';
            $suffix = '';
            if ($desc = \trim((string) $pr->getDescription())) {
                $suffix = ' ' . \mb_substr($desc, 0, 30) . (\mb_strlen($desc) > 30 ? '…' : '');
            }

            if ($start && $endExcl) {
                $calendarEvents[] = [
                    'title' => $labelType . $suffix, // ex: "Stage VL" / "Mission Sentinelle"
                    'start' => $start,
                    'end'   => $endExcl,
                    'allDay'=> true,
                    'backgroundColor' => '#0d6efd',
                    'borderColor'     => '#0d6efd',
                    'textColor'       => '#ffffff',
                ];
            }
        }

        // Fallback de test si vide
        if (empty($calendarEvents)) {
            $today = new \DateTime('today');
            $calendarEvents[] = [
                'title' => 'TEST — Permission',
                'start' => $today->format('Y-m-d'),
                'end'   => $today->modify('+3 days')->format('Y-m-d'),
                'allDay'=> true,
                'backgroundColor' => '#198754',
                'textColor' => '#ffffff',
            ];
            $calendarEvents[] = [
                'title' => 'TEST — Mission',
                'start' => $today->modify('+5 days')->format('Y-m-d'),
                'end'   => $today->modify('+9 days')->format('Y-m-d'),
                'allDay'=> true,
                'backgroundColor' => '#0B2242',
                'textColor' => '#ffffff',
            ];
        }

        return $this->render('militaire/dashboard.html.twig', [
            'user'            => $user,
            'permissions'     => $permissions,
            'programmes'      => $programmes,
            'calendar_events' => $calendarEvents,
            'stats'           => $stats,
            'solde'           => $solde,
        ]);
    }

    #[Route('/historique', name: 'historique', methods: ['GET'])]
    public function historique(): Response
    {
        $user = $this->getUser();
        if (!$user) {
            return $this->redirectToRoute('app_login');
        }

        $permissions = $this->em->getRepository(Permission::class)
            ->findBy(['user' => $user], ['createdAt' => 'DESC']);

        $stats = ['total' => \count($permissions), 'acceptees' => 0, 'refusees' => 0, 'en_attente' => 0];
        foreach ($permissions as $p) {
            $s = strtolower($p->getStatut());
            if (str_contains($s, 'accept'))   $stats['acceptees']++;
            elseif (str_contains($s, 'refus')) $stats['refusees']++;
            else                                $stats['en_attente']++;
        }

        $solde = $this->calculerSoldePermissions($user);

        return $this->render('militaire/historique.html.twig', [
            'permissions' => $permissions,
            'stats'       => $stats,
            'solde'       => $solde,
        ]);
    }

    /** Parse d/m/Y, Y-m-d, d-m-Y ; null si invalide */
    private function parseDateFlexible(?string $value): ?\DateTimeImmutable
    {
        if (!$value = trim((string) $value)) return null;
        foreach (['Y-m-d', 'd/m/Y', 'd-m-Y'] as $fmt) {
            $dt = \DateTimeImmutable::createFromFormat('!' . $fmt, $value);
            if ($dt instanceof \DateTimeImmutable) return $dt;
        }
        $ts = strtotime($value);
        return $ts ? (new \DateTimeImmutable())->setTimestamp($ts) : null;
    }

    /** Calcule le solde des permissions */
    private function calculerSoldePermissions($user): array
    {
        $permissionsAcceptees = $this->em->getRepository(Permission::class)
            ->findBy(['user' => $user, 'statut' => ['acceptée', 'acceptee']]);

        $solde = ['courte' => 15, 'longue' => 30, 'étranger' => 10];

        foreach ($permissionsAcceptees as $p) {
            $debut = $p->getDateDebut();
            $fin   = $p->getDateFin();
            if ($debut && $fin) {
                $jours = $debut->diff($fin)->days + 1; // inclusif
                $type = $p->getType();
                if (isset($solde[$type])) {
                    $solde[$type] = max(0, $solde[$type] - $jours);
                }
            }
        }
        return $solde;
    }

    #[Route('/calendrier/data', name: 'app_militaire_calendrier_data', methods: ['GET'])]
    public function calendrierData(ProgrammeRepository $progRepo): JsonResponse
    {
        $user = $this->getUser();
        if (!$user) return $this->json([]);

        $events = [];

        // 1) Permissions du militaire — vert
        $permissions = $this->em->getRepository(Permission::class)
            ->findBy(['user' => $user]);

        foreach ($permissions as $permission) {
            $start   = $permission->getDateDebut()?->format('Y-m-d');
            $endExcl = $permission->getDateFin()?->modify('+1 day')->format('Y-m-d');

            if ($start && $endExcl) {
                $events[] = [
                    'id'    => 'perm_' . $permission->getId(),
                    'title' => 'Permission ' . $permission->getType(),
                    'start' => $start,
                    'end'   => $endExcl, // fin exclusive
                    'allDay'=> true,
                    'backgroundColor' => match (strtolower($permission->getStatut())) {
                        'acceptée', 'acceptee' => '#198754',
                        'refusée',  'refusee'  => '#dc3545',
                        default                 => '#ffc107',
                    },
                    'borderColor' => '#ffffff',
                    'textColor'   => '#ffffff',
                    'extendedProps' => [
                        'type'   => 'permission',
                        'statut' => $permission->getStatut(),
                        'motif'  => $permission->getMotif()
                    ]
                ];
            }
        }

        // 2) Programmes de l’unité — bleu (Programme.user = officier)
        $programmes = $progRepo->createQueryBuilder('p')
            ->leftJoin('p.user', 'o')
            ->andWhere('o.unite = :unite')
            ->setParameter('unite', $user->getUnite())
            ->getQuery()->getResult();

        foreach ($programmes as $pr) {
            $start   = $pr->getDateDebut()?->format('Y-m-d');
            $endExcl = $pr->getDateFin()?->modify('+1 day')->format('Y-m-d');

            $labelType = $pr->getType() === 'stage' ? 'Stage' : 'Mission';
            $suffix = '';
            if ($desc = \trim((string) $pr->getDescription())) {
                $suffix = ' ' . \mb_substr($desc, 0, 30) . (\mb_strlen($desc) > 30 ? '…' : '');
            }

            if ($start && $endExcl) {
                $events[] = [
                    'id'    => 'prog_' . $pr->getId(),
                    'title' => $labelType . $suffix,
                    'start' => $start,
                    'end'   => $endExcl,
                    'allDay'=> true,
                    'backgroundColor' => '#0d6efd',
                    'borderColor'     => '#0d6efd',
                    'textColor'       => '#ffffff',
                    'extendedProps'   => [
                        'type'        => 'programme',
                        'kind'        => $pr->getType(),
                        'description' => $pr->getDescription(),
                    ],
                ];
            }
        }

        return $this->json($events);
    }
}
