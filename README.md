# Africa Sport Edition

Plateforme de scouting football africain, fournie ici comme site statique avec gestion locale et synchronisation Supabase optionnelle.

## Développement local

Ouvrir `index.html` dans un navigateur pour le mode local. Les données locales restent dans le stockage de ce navigateur. Le code admin `197100` est conservé uniquement dans `ase-config.local.js`, fichier exclu du dépôt Git. Dès que Supabase est configuré, la connexion administrateur passe par Supabase Auth (email et mot de passe) et le code local est ignoré.

## GitHub Pages

Le dépôt contient un workflow GitHub Actions qui prépare le site et le publie sur GitHub Pages à chaque envoi sur `main`. Dans les paramètres du dépôt :

1. Activez Pages avec la source **GitHub Actions**.
2. Ajoutez les secrets `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY`.
3. Envoyez les commits sur `main` ; le lien public apparaît dans l’environnement `github-pages`.

Le site est public une fois Pages activé. Le code navigateur ne contient jamais de clé `service_role`. La clé publishable est intégrée au site et doit être protégée par les règles RLS de la migration.

## Supabase

Voir [`supabase/README.md`](supabase/README.md) pour créer le schéma, promouvoir l’administrateur, déployer la fonction sécurisée d’invitation/suppression et configurer les redirections Auth.

## Données et médias

Les collections partagées sont stockées dans `ase_app_data`. Les demandes, codes et informations d’administration ne sont visibles que par les administrateurs via RLS. Les images sont envoyées au bucket `ase-media` quand un compte actif téléverse ou met à jour un profil. Ce bucket est public pour permettre l’affichage des logos et portraits dans les fiches ; ne placez-y aucun document confidentiel.

## Limites

La synchronisation exige une URL hébergée (par exemple GitHub Pages) autorisée dans Supabase Auth. Ouvrir le site en `file://` ne permet pas le retour des liens de connexion email. Le mode local reste disponible sans Supabase.
