package com.hariverse.hledger.widget

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class ExpenseWidgetReceiver : HomeWidgetGlanceWidgetReceiver<ExpenseWidget>() {
    override val glanceAppWidget = ExpenseWidget()
}
