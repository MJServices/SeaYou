## Aperçu

* Ajouter un système de notifications temps réel pour messages et un module Conversations en cours.

* Brancher l’UI aux données Supabase (messages, conversations) en respectant le design system existant.

* Étendre la barre Feeling avec jalons et déblocages conditionnels.

## Données et Backend

* Créer des lectures/réal‑time pour messages:

  * `DatabaseService.getMessages(conversationId)` (tri `created_at ASC`) et `subscribeMessages(conversationId)` via Postgres Changes, similaire à `subscribeConversation` (`lib/services/database_service.dart:575+`).

* Compteur « nouveaux messages »:

  * Introduire `message_reads (conversation_id, user_id, last_read_at)` pour calcul fiable des non lus.

  * Méthodes: `getUnreadMessagesCount(userId)`, `markConversationRead(conversationId, userId)`.

  * Alternative sans migration: stocker `last_read_at` localement par conversation (moins fiable inter‑device).

* Conversations:

  * `getUserConversations(userId)` existe; compléter avec feeling et dernier message.

  * `renameConversation(conversationId, title)` est prêt côté service; l’UI déclencheur existe (`lib/screens/chat/chat_conversation_screen.dart:296`).

## Gestion d’état

* Conserver le pattern actuel `StatefulWidget + ValueNotifier`.

  * Garder `FeelingController` (`lib/services/feeling_controller.dart:16`) pour feeling/title.

  * Ajouter `MessagesController` (ValueNotifier\<List<Message>> + StreamSubscription) par conversation.

  * Utiliser `StreamBuilder` pour l’historique + nouveaux messages sur la page de conversation.

## Accueil: compteur dynamique

* Emplacement: `HomeScreen` (`lib/screens/home_screen.dart`).

  * Ajouter un badge texte au header: « {n} nouveaux messages » avec mise à jour en temps réel.

  * Souscrire globalement aux `messages` pour l’utilisateur courant; agréger par conversations non lues.

  * UI: petit badge avec couleur `AppColors.primary` et contrastes (ex. sur la barre de nav « Chat » `lib/screens/home_screen.dart:603-617`).

  * Localisation: clé i18n `home.new_messages_count` (ex: "{count} nouveaux messages").

## Tuile « Conversations en cours »

* Réutiliser et adapter `_buildConversationListPreview()` (`lib/screens/home_screen.dart:1274-1362`).

  * Titre: « Conversations en cours ({count}) ».

  * Lien vers `ChatListScreen` (`lib/screens/chat/chat_list_screen.dart`).

  * Chaque entrée: nom personnalisable (icône rename), `FeelingProgress` compact, pastille non‑lu si `unreadCount > 0`.

  * Charger de vraies conversations via `getUserConversations`; ne plus utiliser la liste statique.

## Page Conversation

* Historique:

  * Remplacer `_messages` local par données `getMessages` + `subscribeMessages`.

  * Affichage par ordre chronologique (`created_at ASC`) dans `_buildMessagesList` (`lib/screens/chat/chat_conversation_screen.dart:443-451`).

* Réponse:

  * Conserver champ texte + bouton envoyer (`lib/screens/chat/chat_conversation_screen.dart:792-809`).

  * Pièces jointes:

    * Citation (débloquée à 25%) via `_insertQuote()` (`lib/screens/chat/chat_conversation_screen.dart:817-829`).

    * Voix (à 50%) via `record` déjà présent; bouton micro (`lib/screens/chat/chat_conversation_screen.dart:757-767`).

    * Photo (à 75%) via `image_picker`; respecter bannière surprise `_surpriseRequired` (`lib/screens/chat/chat_conversation_screen.dart:687-699, 779-786`).

* Déblocage conditionnel:

  * Appuyer sur `FeelingController` pour feeling temps réel (`lib/services/feeling_controller.dart:25-35`).

  * 100%: action manuelle de révélation déjà prévue (`lib/screens/chat/chat_conversation_screen.dart:188-193`).

## Barre Feeling + Jalons

* Étendre `FeelingProgress` (`lib/widgets/feeling_progress.dart:3-86`) pour afficher des jalons:

  * 25%: plume (déblocage citation)

  * 50%: note de musique (voix)

  * 75%: cadeau (surprise/photo)

  * 100%: cœur (révélation finale)

* Alignement: icônes positionnées au-dessus/au‑dessous de la barre avec `Stack` + `FractionallySizedBox`.

* Accessibilité: `Semantics` pour chaque icône (« jalon atteint/non atteint »).

## Indicateurs « non lu »

* Conversation list: petite pastille à droite si `unreadCount > 0`.

* Page conversation: marquer comme lu à l’ouverture/scroll bas via `markConversationRead`.

## Accessibilité et Responsiveness

* `Semantics` pour boutons, inputs, icônes; labels localisés.

* Couleurs/contrastes via `AppColors` (`lib/utils/app_colors.dart`).

* Focus visibles et tailles tactiles ≥ 44 px.

* Responsive: contraintes `maxWidth` déjà gérées (`lib/screens/home_screen.dart:157-160`).

## États de chargement et feedback

* Loading: `CircularProgressIndicator` cohérent (primaire) déjà utilisé (`lib/screens/home_screen.dart:295-301`).

* Audios: réutiliser `GlobalAudioController` pour sons de déblocage.

* Haptics: vibration courte lors du passage de jalon.

## Style et i18n

* Respecter `AppTextStyles` et `AppColors` (`lib/utils/app_text_styles.dart`, `lib/utils/app_colors.dart`).

* Ajouter clés i18n FR/EN/ES/DE pour nouveaux libellés.

## Vérification

* Tests unitaires:

  * `FeelingProgress` position des icônes vs pourcentage.

  * Gating: visibilité des actions aux seuils 25/50/75/100.

* Tests d’intégration:

  * Simulation d’events Supabase pour incrément du compteur « nouveaux messages ».

  * Conversation: réception d’un message → liste mise à jour et pastille non‑lu.

## Plan de migration (si validé)

* Script SQL pour `message_reads` table et politiques RLS.

* MAJ `DatabaseService` pour lectures/écritures liées.

* Stratégie de rétro‑compatibilité: fallback local si table absente.

## Livrables

* Nouvelles méthodes service messages + abonnement.

* Compteur d’accueil temps réel « nouveaux messages ».

* Tuile « Conversations en cours » branchée.

* Page conversation branchée aux messages + envois.

* Barre Feeling avec jalons et action 100% manuelle.

* Indicateurs non‑lu et marquage lu.

* Accessibilité, i18n, et tests actualisés.

