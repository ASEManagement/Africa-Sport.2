# Configuration Supabase

1. Créez un projet Supabase et ouvrez **SQL Editor**.
2. Exécutez [`migrations/20261101000000_ase_platform.sql`](migrations/20261101000000_ase_platform.sql).
3. Dans **Authentication → Users**, créez le compte email de l’administrateur.
4. Promouvez ce compte depuis SQL Editor en remplaçant l’adresse :

```sql
update public.ase_profiles
set role = 'admin', status = 'active', updated_at = now()
where email = 'admin@example.com';
```

5. Déployez la fonction d’administration `ase-admin-user` avec Supabase CLI. Son secret `SUPABASE_SERVICE_ROLE_KEY` reste côté Edge Function et ne doit jamais figurer dans le site.
6. Dans **Authentication → URL Configuration**, ajoutez l’URL GitHub Pages comme Site URL et dans les Redirect URLs.
7. Pour GitHub Pages, configurez les secrets de dépôt `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY`. Pour le mode local, renseignez ces deux valeurs dans `ase-config.local.js` (fichier ignoré par Git). Les liens de connexion par email nécessitent une URL HTTP/HTTPS ajoutée aux Redirect URLs Supabase ; `file://` ne peut pas servir d’adresse de retour.

La connexion publique utilise la clé publishable/anon et Supabase Auth. RLS contrôle les tables : un profil nouvellement inscrit reste `pending` jusqu’à validation de l’administrateur. L’interface des comptes s’appuie sur `ase_profiles`, tandis que les données partagées utilisent `ase_app_data`.

La fonction Edge vérifie le JWT du demandeur et son rôle admin avant d’inviter ou supprimer un compte. Les opérations Auth Admin ne sont jamais réalisées depuis le navigateur.

Documentation Supabase : [installation JS/CDN](https://supabase.com/docs/reference/javascript/installing), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) et [sécurisation des Edge Functions](https://supabase.com/docs/guides/functions/auth).
