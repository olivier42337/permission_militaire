<?php

namespace App\Controller\Web;

use App\Entity\Permission;
use App\Entity\Programme;
use App\Entity\User;
use App\Form\ProgrammeType;
use App\Repository\PermissionRepository;
use App\Repository\ProgrammeRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\Form\Extension\Core\Type\ChoiceType;
use Symfony\Component\Form\Extension\Core\Type\DateType;
use Symfony\Component\Form\Extension\Core\Type\EmailType;
use Symfony\Component\Form\Extension\Core\Type\SubmitType;
use Symfony\Component\Form\Extension\Core\Type\TextareaType;
use Symfony\Component\Form\Extension\Core\Type\TextType;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Security\Csrf\CsrfToken;
use Symfony\Component\Security\Csrf\CsrfTokenManagerInterface;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/officier')]
#[IsGranted('ROLE_OFFICIER')]
class OfficierController extends AbstractController
{
    /**
     * Tableau de bord de l'officier avec indicateurs et demandes en attente
     */
    #[Route('/dashboard', name: 'app_officier_dashboard')]
    public function dashboard(PermissionRepository $permissionRepo, ProgrammeRepository $programmeRepo): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $unite = $user->getUnite();

        // Récupération des permissions en attente FILTRÉES par unité avec une requête optimisée
        $permissionsEnAttente = $permissionRepo->createQueryBuilder('p')
            ->leftJoin('p.user', 'u')
            ->where('p.statut = :statut')
            ->andWhere('u.unite = :unite')
            ->setParameter('statut', 'en attente')
            ->setParameter('unite', $unite)
            ->getQuery()
            ->getResult();

        // CALCUL DES INDICATEURS (KPIs)
        
        // KPI: Permissions en attente
        $kpiEnAttente = count($permissionsEnAttente);

        // KPI: Permissions validées ce mois-ci
        $kpiValidees = (int) $permissionRepo->createQueryBuilder('p')
            ->select('COUNT(p.id)')
            ->leftJoin('p.user', 'u')
            ->where('p.statut = :statut')
            ->andWhere('u.unite = :unite')
            ->andWhere('p.createdAt >= :debutMois')
            ->setParameter('statut', 'acceptée')
            ->setParameter('unite', $unite)
            ->setParameter('debutMois', new \DateTime('first day of this month'))
            ->getQuery()
            ->getSingleScalarResult();

        // KPI: Permissions refusées
        $kpiRefusees = (int) $permissionRepo->createQueryBuilder('p')
            ->select('COUNT(p.id)')
            ->leftJoin('p.user', 'u')
            ->where('p.statut = :statut')
            ->andWhere('u.unite = :unite')
            ->setParameter('statut', 'refusée')
            ->setParameter('unite', $unite)
            ->getQuery()
            ->getSingleScalarResult();

        // KPI: Programmes à venir
        $kpiProgrammes = (int) $programmeRepo->createQueryBuilder('p')
            ->select('COUNT(p.id)')
            ->leftJoin('p.user', 'u')
            ->where('p.dateDebut >= :aujourdhui')
            ->andWhere('u.unite = :unite')
            ->setParameter('aujourdhui', new \DateTime())
            ->setParameter('unite', $unite)
            ->getQuery()
            ->getSingleScalarResult();

        // Formatage des demandes pour l'affichage dans le template
        $demandes = [];
        foreach ($permissionsEnAttente as $permission) {
            $militaire = $permission->getUser();
            $demandes[] = [
                'id' => $permission->getId(),
                'militaireNom' => trim(($militaire->getPrenom() ?? '') . ' ' . ($militaire->getNom() ?? $militaire->getEmail())),
                'type' => $permission->getType(),
                'dateDebut' => $permission->getDateDebut(),
                'dateFin' => $permission->getDateFin(),
                'motif' => $permission->getMotif(),
            ];
        }

        // Récupération des dernières actions (audit)
        $audits = $permissionRepo->createQueryBuilder('p')
            ->leftJoin('p.user', 'u')
            ->where('p.statut IN (:statuts)')
            ->andWhere('u.unite = :unite')
            ->orderBy('p.createdAt', 'DESC')
            ->setMaxResults(5)
            ->setParameter('statuts', ['acceptée', 'refusée'])
            ->setParameter('unite', $unite)
            ->getQuery()
            ->getResult();

        $dernieresActions = [];
        foreach ($audits as $permission) {
            $dernieresActions[] = [
                'userNom' => trim(($permission->getUser()?->getPrenom() ?? '') . ' ' . ($permission->getUser()?->getNom() ?? '')),
                'action' => 'Permission ' . $permission->getType() . ' ' . $permission->getStatut(),
                'date' => $permission->getCreatedAt(),
            ];
        }

        return $this->render('officier/dashboard.html.twig', [
            'user' => $user,
            'demandes' => $demandes,
            'kpi_en_attente' => $kpiEnAttente,
            'kpi_validees' => $kpiValidees,
            'kpi_refusees' => $kpiRefusees,
            'kpi_programmes' => $kpiProgrammes,
            'audits' => $dernieresActions,
        ]);
    }

    /**
     * Liste TOUTES les demandes de permissions en attente pour l'unité de l'officier
     * CORRECTION : Utilise une requête DQL avec jointure pour un filtrage efficace
     */
    #[Route('/demandes', name: 'app_officier_demandes')]
    public function demandes(PermissionRepository $repo): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        
        // REQUÊTE CORRIGÉE : Filtrage direct par unité dans la base de données
        $permissions = $repo->createQueryBuilder('p')
            ->leftJoin('p.user', 'u') // Jointure avec l'entité User
            ->where('p.statut = :statut')
            ->andWhere('u.unite = :unite') // Filtre par unité
            ->setParameter('statut', 'en attente')
            ->setParameter('unite', $user->getUnite())
            ->orderBy('p.createdAt', 'DESC') // Tri par date de création
            ->getQuery()
            ->getResult();

        return $this->render('officier/demandes.html.twig', [
            'permissions' => $permissions
        ]);
    }

    /**
     * Validation d'une demande de permission
     * AJOUT : Protection CSRF pour la sécurité
     */
    #[Route('/permission/{id}/valider', name: 'app_officier_permission_valider', methods: ['POST'])]
    public function valider(
        Permission $permission, 
        Request $request, 
        EntityManagerInterface $em,
        CsrfTokenManagerInterface $csrfTokenManager
    ): Response {
        /** @var User $officier */
        $officier = $this->getUser();
        $militaire = $permission->getUser();

        // Vérification que le militaire appartient bien à la même unité
        if (!$militaire || $militaire->getUnite() !== $officier->getUnite()) {
            $this->addFlash('danger', 'Vous n\'êtes pas autorisé à traiter cette demande.');
            return $this->redirectToRoute('app_officier_dashboard');
        }

        // VÉRIFICATION CSRF AJOUTÉE pour la sécurité
        $submittedToken = (string) $request->request->get('_token');
        if (!$csrfTokenManager->isTokenValid(new CsrfToken('validate' . $permission->getId(), $submittedToken))) {
            throw $this->createAccessDeniedException('Jeton CSRF invalide.');
        }

        // Traitement de la validation
        $commentaire = $request->request->get('commentaire', 'Validé par l\'officier');
        $permission->setStatut('acceptée');
        $permission->setCommentaire($commentaire);

        $em->flush();

        $this->addFlash('success', 'Permission validée avec succès.');
        return $this->redirectToRoute('app_officier_demandes');
    }

    /**
     * Refus d'une demande de permission avec raison obligatoire
     */
    #[Route('/permission/{id}/refuser', name: 'app_officier_permission_refuser', methods: ['POST'])]
    public function refuser(
        Permission $permission, 
        Request $request, 
        EntityManagerInterface $em,
        CsrfTokenManagerInterface $csrfTokenManager
    ): Response {
        /** @var User $officier */
        $officier = $this->getUser();
        $militaire = $permission->getUser();

        // Vérification d'autorisation
        if (!$militaire || $militaire->getUnite() !== $officier->getUnite()) {
            $this->addFlash('danger', 'Vous n\'êtes pas autorisé à traiter cette demande.');
            return $this->redirectToRoute('app_officier_dashboard');
        }

        // Vérification CSRF
        $submittedToken = (string) $request->request->get('_token');
        if (!$csrfTokenManager->isTokenValid(new CsrfToken('reject' . $permission->getId(), $submittedToken))) {
            throw $this->createAccessDeniedException('Jeton CSRF invalide.');
        }

        // Validation de la raison de refus
        $raison = (string) $request->request->get('raison_refus', '');
        if (empty($raison)) {
            $this->addFlash('danger', 'Veuillez indiquer la raison du refus.');
            return $this->redirectToRoute('app_officier_demandes');
        }

        // Traitement du refus
        $permission->setStatut('refusée');
        $permission->setCommentaire('Refusé - Raison: ' . $raison);

        $em->flush();

        $this->addFlash('warning', 'Permission refusée. La raison a été enregistrée.');
        return $this->redirectToRoute('app_officier_demandes');
    }

    /**
     * Page calendrier pour visualiser les permissions et programmes
     */
    #[Route('/calendrier', name: 'app_officier_calendrier')]
    public function calendrier(): Response
    {
        return $this->render('officier/calendrier.html.twig');
    }

    /**
     * Endpoint JSON pour alimenter le calendrier FullCalendar
     * Retourne les événements (permissions et programmes) formatés
     */
    #[Route('/calendrier/data', name: 'app_officier_calendrier_data', methods: ['GET'])]
    public function calendrierData(
        PermissionRepository $permissionRepo,
        ProgrammeRepository $programmeRepo
    ): JsonResponse {
        /** @var User $officier */
        $officier = $this->getUser();
        $unite = $officier->getUnite();
        $events = [];

        // 1) PERMISSIONS ACCEPTÉES (couleur verte)
        $permissions = $permissionRepo->createQueryBuilder('p')
            ->leftJoin('p.user', 'u')
            ->where('p.statut = :statut')
            ->andWhere('u.unite = :unite')
            ->setParameter('statut', 'acceptée')
            ->setParameter('unite', $unite)
            ->getQuery()
            ->getResult();

        foreach ($permissions as $permission) {
            $start = $permission->getDateDebut()?->format('Y-m-d');
            $endExcl = $permission->getDateFin()?->modify('+1 day')->format('Y-m-d');
            
            if ($start && $endExcl) {
                $events[] = [
                    'id' => 'perm_' . $permission->getId(),
                    'title' => sprintf('%s %s (%s)',
                        $permission->getUser()?->getPrenom() ?? '',
                        $permission->getUser()?->getNom() ?? '',
                        'Permission ' . $permission->getType()
                    ),
                    'start' => $start,
                    'end' => $endExcl,
                    'allDay' => true,
                    'backgroundColor' => '#198754', // Vert Bootstrap
                    'borderColor' => '#198754',
                    'textColor' => '#FFFFFF',
                    'extendedProps' => [
                        'type' => 'permission',
                        'statut' => $permission->getStatut(),
                        'motif' => $permission->getMotif(),
                    ],
                ];
            }
        }

        // 2) PROGRAMMES/MISSIONS/STAGES (couleur bleue)
        $programmes = $programmeRepo->createQueryBuilder('p')
            ->leftJoin('p.user', 'u')
            ->where('u.unite = :unite')
            ->setParameter('unite', $unite)
            ->getQuery()
            ->getResult();

        foreach ($programmes as $programme) {
            $start = $programme->getDateDebut()?->format('Y-m-d');
            $endExcl = $programme->getDateFin()?->modify('+1 day')->format('Y-m-d');

            $labelType = $programme->getType() === 'stage' ? 'Stage' : 'Mission';
            $suffix = '';
            
            if ($description = trim((string) $programme->getDescription())) {
                $suffix = ' ' . mb_substr($description, 0, 30) . (mb_strlen($description) > 30 ? '…' : '');
            }

            if ($start && $endExcl) {
                $events[] = [
                    'id' => 'prog_' . $programme->getId(),
                    'title' => $labelType . $suffix,
                    'start' => $start,
                    'end' => $endExcl,
                    'allDay' => true,
                    'backgroundColor' => '#0d6efd', // Bleu Bootstrap
                    'borderColor' => '#0d6efd',
                    'textColor' => '#FFFFFF',
                    'extendedProps' => [
                        'type' => 'programme',
                        'kind' => $programme->getType(), // stage|mission
                        'description' => $programme->getDescription(),
                    ],
                ];
            }
        }

        return $this->json($events);
    }

    /**
     * Ajout d'un nouveau programme (mission ou stage)
     */
    #[Route('/programme/ajout', name: 'app_officier_ajouter_programme')]
    public function ajouterProgramme(Request $request, EntityManagerInterface $em): Response
    {
        $programme = new Programme();
        $programme->setUser($this->getUser()); // L'officier connecté est le créateur

        $form = $this->createForm(ProgrammeType::class, $programme);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            $em->persist($programme);
            $em->flush();

            $this->addFlash('success', 'Programme ajouté avec succès.');
            return $this->redirectToRoute('app_officier_dashboard');
        }

        return $this->render('officier/ajouter_programme.html.twig', [
            'form' => $form->createView(),
        ]);
    }

    /**
     * Liste des militaires de l'unité de l'officier
     */
    #[Route('/utilisateurs', name: 'app_officier_liste_utilisateurs')]
    public function listeUtilisateurs(EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        $utilisateurs = $em->getRepository(User::class)
            ->createQueryBuilder('u')
            ->where('u.unite = :unite')
            ->andWhere('u.roles LIKE :role') // Filtre uniquement les militaires
            ->setParameter('unite', $user->getUnite())
            ->setParameter('role', '%ROLE_MILITAIRE%')
            ->getQuery()
            ->getResult();

        return $this->render('officier/utilisateurs.html.twig', [
            'utilisateurs' => $utilisateurs
        ]);
    }

    /**
     * Création d'un nouveau compte militaire
     */
    #[Route('/militaire/ajouter', name: 'app_officier_ajouter_militaire')]
    public function ajouterMilitaire(
        Request $request,
        EntityManagerInterface $em,
        UserPasswordHasherInterface $hasher
    ): Response {
        $user = new User();

        $form = $this->createFormBuilder($user)
            ->add('nom', TextType::class)
            ->add('prenom', TextType::class)
            ->add('email', EmailType::class)
            ->add('grade', TextType::class)
            ->add('unite', TextType::class)
            ->add('password', TextType::class, [
                'label' => 'Mot de passe (défini par l\'officier)'
            ])
            ->add('submit', SubmitType::class, ['label' => 'Créer le compte'])
            ->getForm();

        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            // Hashage du mot de passe
            $hashedPassword = $hasher->hashPassword($user, $user->getPassword());
            $user->setPassword($hashedPassword);
            $user->setRoles(['ROLE_MILITAIRE']);

            $em->persist($user);
            $em->flush();

            $this->addFlash('success', 'Compte militaire créé avec succès.');
            return $this->redirectToRoute('app_officier_liste_utilisateurs');
        }

        return $this->render('officier/ajouter_militaire.html.twig', [
            'form' => $form->createView(),
        ]);
    }

    /**
     * Liste des programmes de l'unité
     */
    #[Route('/programmes', name: 'app_officier_liste_programmes')]
    public function listeProgrammes(ProgrammeRepository $repo): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        $programmes = $repo->createQueryBuilder('p')
            ->leftJoin('p.user', 'u')
            ->where('u.unite = :unite')
            ->orderBy('p.dateDebut', 'DESC')
            ->setParameter('unite', $user->getUnite())
            ->getQuery()
            ->getResult();

        return $this->render('officier/liste_programmes.html.twig', [
            'programmes' => $programmes
        ]);
    }

    /**
     * Modification d'un compte militaire existant
     */
    #[Route('/militaire/{id}/modifier', name: 'modifier_militaire')]
    public function modifierMilitaire(
        int $id,
        Request $request,
        EntityManagerInterface $em,
        UserPasswordHasherInterface $hasher
    ): Response {
        $user = $em->getRepository(User::class)->find($id);
        
        if (!$user) {
            throw $this->createNotFoundException('Militaire non trouvé.');
        }

        // Vérification stricte de l'unité pour la sécurité
        if ($user->getUnite() !== $this->getUser()->getUnite()) {
            $this->addFlash('danger', 'Vous n\'êtes pas autorisé à modifier ce militaire.');
            return $this->redirectToRoute('app_officier_liste_utilisateurs');
        }

        $form = $this->createFormBuilder($user)
            ->add('nom', TextType::class)
            ->add('prenom', TextType::class)
            ->add('email', EmailType::class)
            ->add('grade', TextType::class)
            ->add('unite', TextType::class)
            ->add('password', TextType::class, [
                'label' => 'Nouveau mot de passe (optionnel)',
                'required' => false
            ])
            ->add('submit', SubmitType::class, ['label' => 'Enregistrer'])
            ->getForm();

        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            // Mise à jour du mot de passe seulement si fourni
            if ($form->get('password')->getData()) {
                $hashedPassword = $hasher->hashPassword($user, $form->get('password')->getData());
                $user->setPassword($hashedPassword);
            }

            $em->flush();
            $this->addFlash('success', 'Le compte militaire a été mis à jour.');
            return $this->redirectToRoute('app_officier_liste_utilisateurs');
        }

        return $this->render('officier/modifier_militaire.html.twig', [
            'form' => $form->createView(),
        ]);
    }

    /**
     * Suppression d'un compte militaire avec protection CSRF
     */
    #[Route('/militaire/{id}/supprimer', name: 'supprimer_militaire', methods: ['POST'])]
    public function supprimerMilitaire(
        int $id,
        Request $request,
        EntityManagerInterface $em,
        CsrfTokenManagerInterface $csrfTokenManager
    ): Response {
        $user = $em->getRepository(User::class)->find($id);
        
        if (!$user) {
            throw $this->createNotFoundException('Militaire introuvable.');
        }

        // Vérification de l'unité
        if ($user->getUnite() !== $this->getUser()->getUnite()) {
            $this->addFlash('danger', 'Vous n\'êtes pas autorisé à supprimer ce militaire.');
            return $this->redirectToRoute('app_officier_liste_utilisateurs');
        }

        // Validation CSRF stricte
        $submittedToken = (string) $request->request->get('_token');
        if (!$csrfTokenManager->isTokenValid(new CsrfToken('delete' . $user->getId(), $submittedToken))) {
            throw $this->createAccessDeniedException('Jeton CSRF invalide.');
        }

        $em->remove($user);
        $em->flush();

        $this->addFlash('success', 'Militaire supprimé avec succès.');
        return $this->redirectToRoute('app_officier_liste_utilisateurs');
    }
}