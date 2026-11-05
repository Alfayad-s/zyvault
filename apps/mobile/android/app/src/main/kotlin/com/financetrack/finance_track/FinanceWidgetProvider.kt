package com.financetrack.finance_track

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class FinanceWidgetProvider : HomeWidgetProvider() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != toggleAction) {
      super.onReceive(context, intent)
      return
    }
    val prefs = HomeWidgetPlugin.getData(context)
    prefs.edit().putBoolean(eyeHiddenKey, !prefs.getBoolean(eyeHiddenKey, false)).apply()
    val manager = AppWidgetManager.getInstance(context)
    val ids = manager.getAppWidgetIds(android.content.ComponentName(context, javaClass))
    onUpdate(context, manager, ids, prefs)
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val hidden = widgetData.getBoolean(eyeHiddenKey, false)
    for (id in appWidgetIds) {
      val views =
          RemoteViews(context.packageName, R.layout.finance_widget).apply {
            widgetData.getString("widget_title", null)?.let { setTextViewText(R.id.widget_title, it) }
            val balance = widgetData.getString("widget_balance", null)
            if (balance != null) {
              setTextViewText(R.id.widget_balance, if (hidden) "₹ ••••" else balance)
            }
            widgetData.getString("widget_spent", null)?.let { setTextViewText(R.id.widget_spent, it) }
            setImageViewResource(
                R.id.widget_eye,
                if (hidden) R.drawable.widget_eye_off else R.drawable.widget_eye,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
              setContentDescription(
                  R.id.widget_eye,
                  context.getString(
                      if (hidden) R.string.widget_show_balance else R.string.widget_hide_balance),
              )
            }
            setOnClickPendingIntent(R.id.widget_eye, toggleIntent(context))
            setOnClickPendingIntent(
                R.id.widget_balance_card,
                HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("financetrack://home")),
            )
            setOnClickPendingIntent(
                R.id.widget_speak,
                HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("financetrack://type?voice=1")),
            )
            setOnClickPendingIntent(
                R.id.widget_type,
                HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("financetrack://type")),
            )
          }
      appWidgetManager.updateAppWidget(id, views)
    }
  }

  private fun toggleIntent(context: Context): PendingIntent {
    val intent =
        Intent(context, FinanceWidgetProvider::class.java).apply { action = toggleAction }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    return PendingIntent.getBroadcast(context, 0, intent, flags)
  }

  companion object {
    private const val toggleAction = "com.financetrack.finance_track.TOGGLE_BALANCE"
    private const val eyeHiddenKey = "widget_eye_hidden"
  }
}
