# HLedger Privacy Policy

**Last updated: August 20, 2026**

HLedger is built privacy-first. Your financial data is your own. This policy
explains what we access, why, and where it lives. In short: **nothing leaves
your device except what is needed to sign you in and sync entries back to your
own account.**

---

## 1. Data We Collect

HLedger stores the expense and income entries you create, your notes, tasks,
and categories. When you turn on the optional auto-detect feature, we read
transaction alerts from your bank and UPI apps — from their notifications, from
their SMS, or both, depending on which sources you enable — to detect the amount
and direction (money in or out). We do not collect your contacts, location,
photos, or browsing activity.

## 2. Where Your Data Lives

Detected transactions waiting for your review, and your chat history, stay on
your device and are never uploaded. **Raw SMS text and raw notification text
never leave your device at any point.** Entries you save are stored on your
device and synced to your own private account so they survive a reinstall or a
new phone — see section 7. This data is never sold or shared with third parties.
Uninstalling the app removes the local copy.

## 3. Notification Access (optional)

With your explicit consent, HLedger uses Android's Notification Listener to read
incoming transaction alerts from bank and UPI apps. We use this **only** to
suggest expense entries that you review before saving.

We read notifications from a fixed allowlist of banking, UPI and wallet apps
only. Notifications from every other app on your device — messaging, email,
social, health, everything else — are not opened and not stored; only the fact
that an unrecognised app posted something is noted on-device for diagnostics.
Captured alerts are held in encrypted app-private storage on your device until
you review them, then deleted.

You can revoke this access anytime from your phone **Settings > Notification
access**, or from the Review Inbox inside HLedger.

## 4. SMS Access (optional)

With your explicit consent — shown before Android's permission prompt — HLedger
requests `READ_SMS` and `RECEIVE_SMS` to detect transactions from the SMS your
bank sends you. This exists because many Indian banks announce a transaction
**only** by SMS, and those transactions are otherwise invisible to the app.

What we do with SMS:

- We read the message **body and sender** only to extract an amount, a direction,
  a counterparty and a reference number.
- Messages from an ordinary phone number are **discarded without being parsed** —
  only institutional senders are processed.
- We never read one-time passwords. Messages containing an OTP are rejected
  before any figure is extracted.
- **We never send SMS.** `SEND_SMS` is not requested and never will be.
- **Raw SMS content is never transmitted off the device**, never sent to our
  servers (we have none), and never sent to any third party — including the AI
  provider described in section 6.

You can revoke SMS access anytime from **Settings > Apps > HLedger >
Permissions > SMS**. Auto-detect then stops; everything else in the app keeps
working, and you can add transactions manually or by chat.

## 5. Auto-detect Is Not Complete, By Design

Auto-detect is a convenience, not a system of record. Cash transactions cannot
be detected at all, and some apps and banks announce transactions in ways the app
cannot read. **Every detected transaction is shown to you for confirmation before
it is saved**, and anything missed can be added manually. HLedger never books an
entry to your ledger without your explicit confirmation.

## 6. AI Chat Assistant

If you use the in-app AI chat, the messages you type are sent to the **Groq API**
(groq.com), and if Groq is unavailable to the **Google Gemini API**
(generativelanguage.googleapis.com), so a model can generate a reply. Only the
text you choose to send in chat leaves the device for this feature, along with
the recent chat turns needed for context.

Your stored transactions, your SMS, and your notifications are **not** sent to
either provider unless you personally type that information into a chat message.
Please review Groq's and Google's own privacy terms for how they handle requests.
Do not share sensitive information in chat.

## 7. Authentication & Sync

Account sign-in and sync are powered by **Google Firebase** — Firebase
Authentication for sign-in and Cloud Firestore for sync. When you create an
account we store your email and authentication details with Firebase to keep you
signed in, and the entries you save are written to your own area of the
database. Security rules restrict every record to the account that created it,
so no other user can read your data. Review Google's privacy terms for how they
handle this.

## 8. No Third-Party Sharing

We do not sell your data. We do not share your financial data with advertisers
or data brokers. The only external services involved are the ones described
above (Groq and Google Gemini for AI chat, Google Firebase for authentication
and sync), used solely to provide those features.

## 9. Your Rights

You control your data. You can delete individual entries, clear all local data,
revoke notification and SMS access, and delete your account. Uninstalling the app
removes on-device data. To request account deletion or a data export, contact
us using the details below.

## 10. Children's Privacy

HLedger is not directed at children under 13, and we do not knowingly collect
data from them.

## 11. Changes to This Policy

We may update this policy from time to time. Material changes will be reflected
here with a new "Last updated" date.

## 12. Contact

Questions about privacy? Reach out at **guptahariom049@gmail.com**.

---

*By using HLedger you agree to this Privacy Policy.*


