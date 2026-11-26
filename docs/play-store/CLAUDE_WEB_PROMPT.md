# Prompt for Claude (web + Claude in Chrome): publish HomeCircle to Google Play

Copy everything below the line into Claude on the web with the Claude in Chrome extension connected.
Fill in the three `<<...>>` values first (reviewer test account and tester emails).

---

You are helping me publish my Android app **HomeCircle** on Google Play using my Chrome browser (Claude in Chrome). I am already signed in to Google Play Console and GitHub in Chrome. Work through the steps below in order, filling every form with the information given here. Do not invent facts. If a form asks for something not covered here, stop and ask me.

**Rules**
- Use only the facts in this prompt. Where I gave exact text, paste it exactly.
- Some steps need files from my computer (AAB, screenshots, graphics). The browser extension cannot pick local files, so when you reach a file upload, stop and tell me exactly which file to drag in. Continue after I confirm.
- Never click **"Send for review"**, **"Start rollout"**, **"Publish"** or anything that makes the app public, or that starts a review, without first summarising what will happen and getting my explicit "yes".
- Never pay for anything, change account or payment settings, or delete anything.
- After each major section, give me a one-line status.

## 1. About the app (context)

- **App name:** HomeCircle
- **Package name:** `com.homecircle.homecircle`
- **Version:** 1.0.0 (version code 1). This is the first ever upload.
- **What it does:** a household organiser for families who live together. One household is shared by all its members, who see the same data live.
  - Shared **inventory**: groceries, supplies and appliances, with stock levels, low-stock alerts, condition tracking and item photos.
  - **Tasks and requests**: chores, repair reports and requests, with assignees, priorities, due dates, comments and progress.
  - Shared **shopping list**: add, assign and check off items, and optionally update inventory after purchase.
  - **Family chat**: household group chat with photos, where any message can become a task or shopping item.
  - **Activity feed and notifications**: who changed what, plus push notifications.
  - Households are joined with invite codes. Members have admin or member roles.
- **Price:** free. **No ads. No in-app purchases. No subscriptions.**
- **Login:** required (email + password). Users create an account inside the app.
- **Tech/providers:** Flutter app; backend API on Render; database, auth and photo storage on Supabase; push via Firebase Cloud Messaging. No analytics or advertising SDKs. All traffic is HTTPS.
- **Permissions:** Internet and Notifications only. The app picks photos with the system photo picker (no broad storage permission), with no location, contacts, camera background use or SMS.
- **Developer / support email:** abdulhadijalil34@gmail.com
- **GitHub repository:** https://github.com/Abdul-Hadi-Jalil/homecircle

## 2. Turn on GitHub Pages (privacy policy hosting)

The pages are already written and pushed to the `gh-pages` branch.

1. Open https://github.com/Abdul-Hadi-Jalil/homecircle/settings/pages
2. Under **Build and deployment → Source**, choose **Deploy from a branch**. Set branch **gh-pages** and folder **/ (root)**, then **Save**.
3. Wait 1–3 minutes, then confirm these load (refresh until they do):
   - Website: https://abdul-hadi-jalil.github.io/homecircle/
   - Privacy policy: https://abdul-hadi-jalil.github.io/homecircle/privacy.html
   - Account deletion: https://abdul-hadi-jalil.github.io/homecircle/delete-account.html

## 3. Create the app in Play Console

Go to https://play.google.com/console → **Create app**:
- App name: **HomeCircle**
- Default language: **English (United States) – en-US**
- App or game: **App**
- Free or paid: **Free**
- Tick the Developer Program Policies and US export laws declarations.

## 4. App content (Policy → App content)

Complete every declaration:

- **Privacy policy:** `https://abdul-hadi-jalil.github.io/homecircle/privacy.html`
- **App access:** "All or some functionality is restricted". Add instructions:
  - Name: `Reviewer account`
  - Username: `<<REVIEWER_EMAIL>>`
  - Password: `<<REVIEWER_PASSWORD>>`
  - Other info: `Sign in with the account above. It already belongs to a sample household with inventory, tasks, shopping items and chat messages. All features are available after sign-in; no payment or extra codes are needed.`
- **Ads:** No, the app does not contain ads.
- **Content rating:** start the questionnaire. Email: abdulhadijalil34@gmail.com. Category: **"All other app types"** (utility/productivity/communication). Answers:
  - Violence, sexuality, language, controlled substances, gambling, horror/fear: **No** to all.
  - Do users interact or exchange content with each other? **Yes**. Members of the same private household can chat and share photos and items.
  - Does the app share the user's current physical location with other users? **No**
  - Does the app allow users to purchase digital goods? **No**
  - Unrestricted internet browsing? **No**
  - Is the app a web browser or search engine? **No**
- **Target audience and content:** target age group **18 and over** only. Answer that the app is **not** designed to appeal to children.
- **News app:** No.
- **COVID-19 contact tracing/status:** No (not such an app).
- **Data safety** (answer exactly):
  - Does the app collect or share any required user data types? **Yes**
  - Is all user data encrypted in transit? **Yes**
  - Do you provide a way for users to request that their data is deleted? **Yes**. Deletion URL: `https://abdul-hadi-jalil.github.io/homecircle/delete-account.html`
  - **Data types collected** (none are **shared** with third parties; service providers acting on our behalf don't count as sharing). None are processed ephemerally. Purposes as listed:
    - Personal info → **Email address**: collected, required. Purposes: App functionality, Account management.
    - Personal info → **Name**: collected, required (display name). Purposes: App functionality, Account management.
    - Messages → **Other in-app messages**: collected, optional (household chat). Purpose: App functionality.
    - Photos and videos → **Photos**: collected, optional (item, task and chat photos). Purpose: App functionality.
    - App activity → **Other user-generated content**: collected, required (inventory items, tasks, shopping items, household names). Purpose: App functionality.
    - Device or other IDs → **Device or other IDs**: collected, optional (push notification token). Purpose: App functionality.
  - Not collected: location, financial info, health, contacts, calendar, audio, files and docs, web browsing, app interactions/analytics, crash logs, advertising ID.
- **Government app:** No. **Financial features:** none. **Health:** none.
- **Account deletion** (if asked separately): the app lets users create accounts. Deletion is available in-app (*Profile → Delete account*, which opens the deletion page) and on the web at the deletion URL above.

## 5. Main store listing (Grow → Store presence → Main store listing)

- **App name:** `HomeCircle: Family Home Hub`
- **Short description** (≤80 chars):
  `Shared inventory, chores, shopping list and family chat for your home.`
- **Full description:**

```
HomeCircle keeps everything your home needs in one shared place, so the whole family stays in sync.

SHARED INVENTORY
• Track groceries, supplies and appliances by category and location
• See stock levels at a glance and get low-stock alerts
• Update quantities in one tap and keep photos of important items
• Log the condition of appliances and report what needs fixing

TASKS & REQUESTS
• Create chores, repair reports and requests in seconds
• Assign them to family members with priorities and due dates
• Track progress, add updates and attach photos
• Know exactly what is urgent and what is done

ONE SHOPPING LIST FOR EVERYONE
• Anyone can add what the household needs
• Assign items, mark urgency and check things off as you shop
• Update your inventory automatically after a purchase

FAMILY CHAT
• A private group chat for the people you live with
• Share photos and turn any message into a task or shopping item

STAY IN THE LOOP
• Live dashboard of pending tasks, urgent issues and low stock
• Activity feed showing who changed what
• Notifications for assignments, low stock and new messages

PRIVATE BY DESIGN
• Only members of your household can see its data
• Invite family with a secure code and manage roles
• No ads, no tracking

Create a household, invite your family and start running your home together.
```

- **App icon:** upload `docs/play-store/app-icon-512.png` (ask me to drag it in).
- **Feature graphic:** `docs/play-store/feature-graphic.png` (1024×500).
- **Phone screenshots** (in this order): `docs/play-store/screenshots/01_dashboard.png`, `02_inventory.png`, `03_stock.png`, `04_tasks.png`, `05_repairs.png`, `06_shopping.png`, `07_chat.png`.
- Leave tablet and Chromebook screenshots empty.
- **Store settings** (Store presence → Store settings): App category **House & Home**. Tags: household, family organizer, shopping list, to-do list, home inventory (pick the closest available ones). Contact email `abdulhadijalil34@gmail.com`. Website `https://abdul-hadi-jalil.github.io/homecircle/`. No phone number.

## 6. Closed testing release

1. **Testing → Closed testing → Create track** (or use the default "Closed testing - Alpha" track).
2. **Testers:** create an email list named `HomeCircle testers` with these addresses:
   `<<TESTER_EMAILS_COMMA_SEPARATED>>`
   Set the feedback URL/email to `abdulhadijalil34@gmail.com`.
3. **Countries/regions:** add all countries.
4. **Create new release:**
   - Accept **Play App Signing** if asked. The upload key is my existing release key.
   - App bundle: ask me to upload `mobile/build/app/outputs/bundle/release/app-release.aab` (version 1.0.0, code 1).
   - Release name: `1.0.0 (1)`
   - Release notes (en-US):
     ```
     First test release of HomeCircle: shared inventory, tasks and repairs, family shopping list, household chat and notifications.
     ```
5. Review the release and fix every error the console shows. Warnings that only recommend things (such as missing tablet screenshots) can be left.
6. **Stop and ask me** before clicking **Send for review / Start rollout to Closed testing**.
7. After it's approved, copy the **opt-in link** for testers and give it to me.

## 7. Production (later, not now)

Note for me at the end: if this is a **personal** developer account created after November 2023, production access needs a closed test with **at least 12 testers opted in for 14 consecutive days**. After that, apply for production in the Dashboard. Do **not** create a production release in this session.

## 8. Final report

When done, give me:
- Which sections are complete, and anything still waiting on me
- The GitHub Pages URLs, confirmed working
- The closed-testing opt-in link (if available)
- Any policy warnings the console showed
