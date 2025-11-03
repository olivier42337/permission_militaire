<?php

namespace App\Controller\Api;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Annotation\Route;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Security\Core\User\UserProviderInterface;

#[Route('/api')]
class AuthApiController extends AbstractController
{
    #[Route('/login', name: 'api_login', methods: ['POST'])]
    public function login(
        Request $request,
        UserProviderInterface $userProvider,
        UserPasswordHasherInterface $passwordHasher,
        JWTTokenManagerInterface $JWTManager
    ): JsonResponse {
        $data = json_decode($request->getContent(), true);

        // Utilisez 'email' au lieu de 'username' pour correspondre à votre configuration
        if (!isset($data['email'], $data['password'])) {
            return new JsonResponse(['error' => 'Identifiants incomplets'], 400);
        }

        try {
            $user = $userProvider->loadUserByIdentifier($data['email']);

            // Vérifiez le mot de passe
            if (!$passwordHasher->isPasswordValid($user, $data['password'])) {
                return new JsonResponse(['error' => 'Identifiants invalides'], 401);
            }

            // Génère le token JWT
            $jwt = $JWTManager->create($user);

            return new JsonResponse([
                'token' => $jwt,
                'user' => [
                    'email' => $user->getEmail(),
                    'roles' => $user->getRoles()
                ]
            ]);
        } catch (\Exception $e) {
            return new JsonResponse(['error' => 'Identifiants invalides'], 401);
        }
    }
}