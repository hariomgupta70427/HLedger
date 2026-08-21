package com.hariverse.hledger.detection

/**
 * The single place that decides which apps may be read.
 *
 * An allowlist, never a blocklist. A notification listener can see everything on
 * the device — chat, mail, dating, health — so anything not named here is never
 * opened, never stored and never parsed. Failing closed is the only safe
 * direction: a missed transaction is an inconvenience, mining someone's private
 * messages for figures is not.
 *
 * Entries marked VERIFIED were confirmed present on a real device. The rest are
 * published package ids for apps that were not installed there. A wrong id is
 * harmless — it simply never matches — but it also never helps, which is why
 * [CaptureStore.recordSkip] names every source it passes over: the list is meant
 * to grow from evidence, not from guesses.
 */
object TransactionSources {

    private val allowed = setOf(
        // ── UPI apps ──
        "com.google.android.apps.nbu.paisa.user",     // Google Pay — VERIFIED
        "com.google.android.apps.nbu.paisa.merchant", // GPay for Business — VERIFIED
        "com.phonepe.app",                            // VERIFIED
        "com.phonepe.app.business",                   // VERIFIED
        "net.one97.paytm",                            // VERIFIED
        "com.paytm.business",                         // VERIFIED
        "in.org.npci.upiapp",                         // BHIM — VERIFIED (posts alerts)
        "com.google.android.apps.walletnfcrel",       // Google Wallet
        "com.whatsapp.payments",                      // WhatsApp Pay — payments only,
                                                      // a separate package from chat

        // Amazon Pay ships inside the Amazon shopping app; there is no separate
        // package. It was excluded here on the theory that order-update
        // notifications would produce false positives, and that exclusion is
        // exactly why a real received payment went undetected. Order updates
        // carry no settlement participle, so the parser rejects them anyway.
        "in.amazon.mShop.android.shopping",           // VERIFIED

        // ── Neobanks, wallets and credit ──
        "com.dreamplug.androidapp",   // CRED — VERIFIED
        "com.epifi.paisa",            // Fi Money — VERIFIED
        "money.jupiter",              // Jupiter — VERIFIED
        "money.super.payments",       // super.money — VERIFIED
        "com.naviapp",                // Navi — VERIFIED
        "com.mobikwik_new",           // VERIFIED
        "com.hdfcbank.payzapp",       // VERIFIED
        "org.altruist.BajajExperia",  // Bajaj Finserv — VERIFIED
        "com.myairtelapp",            // Airtel Payments Bank — VERIFIED
        "com.vivo.unionpay",          // vivo Wallet — VERIFIED
        "com.freecharge.android",
        "com.phonepe.simpl",
        "in.lazypay.android",
        "com.onecard.android",
        "com.fampay.in",
        // slice was reported as the source of a missed payment but was not
        // installed on the test device, so its id could not be confirmed. Both
        // published forms are listed; the skip log will name the real one the
        // first time slice posts an alert.
        "com.sliceit.android",
        "in.slice.android",

        // ── Bank apps ──
        "com.axis.mobile",                  // Axis Mobile — VERIFIED
        "com.csam.icici.bank.imobile",      // iMobile Pay — VERIFIED
        "com.sbi.lotusintouch",             // YONO SBI — VERIFIED
        "com.ge.capital.konysbiapp",        // SBI Card — VERIFIED
        "in.irisbyyes.app",                 // YES Bank iris — VERIFIED
        // Kotak's id is not the documented com.msf.kbank.mobile on current
        // installs — VERIFIED from the device, and it does post alerts.
        "com.kotak811mobilebankingapp.instantsavingsupiscanandpayrecharge",
        "com.snapwork.hdfc",                // HDFC MobileBanking
        "com.sbi.SBIFreedomPlus",
        "com.bankofbaroda.mconnect",
        "com.idfcfirstbank.optimus",
        "com.indusind.indusmobile",
        "com.rblbank.mobank",
        "com.unionbankofindia.vyom",
        "com.fss.pnbpsp",
        "com.canarabank.mobility",
        "com.infrasofttech.CentralBank",
        "com.aubank.aumobile",
        "com.fedmobile",
        "com.bankofindia.boiapp",
    )

    /**
     * Deliberately NOT allowlisted, and why — so these are not "forgotten"
     * and quietly re-added later:
     *
     * - Chat, social and mail (WhatsApp, Snapchat, Discord, Gmail, …). Never.
     *   This is the entire reason the list is an allowlist.
     * - Broking and portfolio apps (Zerodha Kite/Coin, Angel One, Groww,
     *   INDmoney). Installed on the test device, but their notifications are
     *   overwhelmingly market and portfolio alerts. "Purchased 10 shares at
     *   Rs 250" would book Rs 250 as a spend, which is a wrong number, not just
     *   a missed one.
     * - Crypto wallets (Trust Wallet). Not INR transaction alerts.
     * - Telecom super-apps (MyJio). Recharge promotions dominate, and the
     *   payment itself is announced by the bank or UPI app as well.
     */
    fun isTrusted(packageName: String): Boolean = packageName in allowed
}
