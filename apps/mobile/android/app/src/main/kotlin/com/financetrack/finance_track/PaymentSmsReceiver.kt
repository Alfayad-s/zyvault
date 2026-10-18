package com.financetrack.finance_track

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/** A bank debit or credit read from an SMS. */
data class PaymentText(val amount: String, val credit: Boolean, val sender: String)

object PaymentSms {
  private val amount = Regex("""(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)""", RegexOption.IGNORE_CASE)
  private val credit = Regex("""\b(credited|received|deposited|refunded|refund)\b""", RegexOption.IGNORE_CASE)
  private val debit =
      Regex("""\b(debited|spent|sent|paid|withdrawn|withdrawal|purchase|transferred|deducted)\b""", RegexOption.IGNORE_CASE)
  private val ignore =
      Regex(
          """\b(otp|one time password|verification code|is your code|pre-approved|special offer|exclusive offer|offer valid|apply now|due on|due date|statement is|will be debited|has requested|collect request|mandate|reminder)\b""",
          RegexOption.IGNORE_CASE,
      )

  /** The same rule as the app: the longest dash-separated part, e.g. AX-HDFCBK-S -> HDFCBK. */
  fun senderKey(sender: String): String =
      sender.split("-").maxByOrNull { it.length }?.uppercase() ?: sender.uppercase()

  fun read(sender: String, body: String): PaymentText? {
    if (sender.isBlank() || !sender.any { it.isLetter() }) return null
    if (ignore.containsMatchIn(body)) return null
    val isCredit = credit.containsMatchIn(body)
    val isDebit = debit.containsMatchIn(body)
    if (!isCredit && !isDebit) return null
    val found = amount.find(body) ?: return null
    val value = found.groupValues[1].trimEnd('.', ',')
    if (value.replace(",", "").toDoubleOrNull()?.let { it > 0 } != true) return null
    return PaymentText(value, isCredit && !isDebit, senderKey(sender))
  }
}

class PaymentSmsReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    if (!prefs.getBoolean("flutter.sms_enabled", false)) return
    if (!prefs.getBoolean("flutter.payment_alerts", true)) return
    val foregroundAt = prefs.getLong("flutter.foreground_at", 0L)
    if (System.currentTimeMillis() - foregroundAt < 60_000L) return
    val spam = (prefs.getString("flutter.sms_spam_plain", "") ?: "")
        .split(",")
        .filter { it.isNotBlank() }
        .toSet()
    val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
    messages
        .groupBy { it.displayOriginatingAddress ?: "" }
        .forEach { (sender, parts) ->
          val body = parts.joinToString("") { it.displayMessageBody ?: "" }
          val payment = PaymentSms.read(sender, body) ?: return@forEach
          if (spam.contains(payment.sender)) return@forEach
          show(context, payment, body)
        }
  }

  private fun show(context: Context, payment: PaymentText, body: String) {
    val manager = NotificationManagerCompat.from(context)
    if (!manager.areNotificationsEnabled()) return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel =
          NotificationChannel(CHANNEL, "New payments", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "A bank SMS or UPI app showed a new debit or credit"
          }
      context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }
    val open =
        PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    val title =
        if (payment.credit) "₹${payment.amount} received · ${payment.sender}"
        else "₹${payment.amount} debited · ${payment.sender}"
    val notification =
        NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_payment)
            .setColor(0xFFC8F57A.toInt())
            .setContentTitle(title)
            .setContentText("Tap to save it in zyvault")
            .setStyle(NotificationCompat.BigTextStyle().bigText("$body\n\nTap to save it in zyvault"))
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
    try {
      manager.notify(NOTIFICATION_BASE + (body.hashCode() and 0xFFFFF), notification)
    } catch (_: SecurityException) {}
  }

  companion object {
    const val CHANNEL = "payments"
    const val NOTIFICATION_BASE = 3_000_000
  }
}
