package com.financetrack.finance_track

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FinanceWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (id in appWidgetIds) {
      val views =
          RemoteViews(context.packageName, R.layout.finance_widget).apply {
            widgetData.getString("widget_title", null)?.let { setTextViewText(R.id.widget_title, it) }
            widgetData.getString("widget_balance", null)?.let {
              setTextViewText(R.id.widget_balance, it)
            }
            widgetData.getString("widget_spent", null)?.let { setTextViewText(R.id.widget_spent, it) }
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
}
