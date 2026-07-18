package com.hariverse.hledger.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.*
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.cornerRadius
import androidx.glance.ImageProvider
import androidx.glance.Image
import androidx.glance.ColorFilter
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import com.hariverse.hledger.MainActivity

class ExpenseWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                ExpenseWidgetContent(context, currentState())
            }
        }
    }

    @Composable
    private fun ExpenseWidgetContent(context: Context, state: HomeWidgetGlanceState) {
        val prefs = state.preferences
        val todaySpend = prefs.getString("today_spend", "₹0") ?: "₹0"
        val monthSpend = prefs.getString("month_spend", "₹0") ?: "₹0"
        val monthIncome = prefs.getString("month_income", "₹0") ?: "₹0"
        val lastTxn1 = prefs.getString("last_txn_1", "") ?: ""
        val lastTxn2 = prefs.getString("last_txn_2", "") ?: ""
        val lastTxn3 = prefs.getString("last_txn_3", "") ?: ""

        val bgColor = ColorProvider(android.graphics.Color.parseColor("#13131A"))
        val surfaceColor = ColorProvider(android.graphics.Color.parseColor("#1C1C26"))
        val accentColor = ColorProvider(android.graphics.Color.parseColor("#6C63FF"))
        val greenColor = ColorProvider(android.graphics.Color.parseColor("#00D68F"))
        val redColor = ColorProvider(android.graphics.Color.parseColor("#FF4757"))
        val textPrimary = ColorProvider(android.graphics.Color.parseColor("#FFFFFF"))
        val textSecondary = ColorProvider(android.graphics.Color.parseColor("#8B8FA8"))

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(bgColor)
                .cornerRadius(20.dp)
                .padding(16.dp)
                .clickable(actionStartActivity<MainActivity>()),
        ) {
            // Header
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "💰 HLedger",
                    style = TextStyle(
                        color = accentColor,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Spacer(modifier = GlanceModifier.defaultWeight())
                Text(
                    text = "Today",
                    style = TextStyle(
                        color = textSecondary,
                        fontSize = 11.sp,
                    ),
                )
            }

            Spacer(modifier = GlanceModifier.height(12.dp))

            // Stats Row
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
            ) {
                // Today's Spend
                Column(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .background(surfaceColor)
                        .cornerRadius(12.dp)
                        .padding(10.dp),
                ) {
                    Text(
                        text = "Spent Today",
                        style = TextStyle(color = textSecondary, fontSize = 10.sp),
                    )
                    Spacer(modifier = GlanceModifier.height(4.dp))
                    Text(
                        text = todaySpend,
                        style = TextStyle(
                            color = redColor,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                }

                Spacer(modifier = GlanceModifier.width(8.dp))

                // Month Income
                Column(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .background(surfaceColor)
                        .cornerRadius(12.dp)
                        .padding(10.dp),
                ) {
                    Text(
                        text = "Month Income",
                        style = TextStyle(color = textSecondary, fontSize = 10.sp),
                    )
                    Spacer(modifier = GlanceModifier.height(4.dp))
                    Text(
                        text = monthIncome,
                        style = TextStyle(
                            color = greenColor,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                }
            }

            Spacer(modifier = GlanceModifier.height(10.dp))

            // Month total
            Row(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .background(surfaceColor)
                    .cornerRadius(12.dp)
                    .padding(horizontal = 10.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Month Expense",
                    style = TextStyle(color = textSecondary, fontSize = 11.sp),
                )
                Spacer(modifier = GlanceModifier.defaultWeight())
                Text(
                    text = monthSpend,
                    style = TextStyle(
                        color = textPrimary,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }

            // Recent transactions
            if (lastTxn1.isNotEmpty()) {
                Spacer(modifier = GlanceModifier.height(8.dp))
                Text(
                    text = "Recent",
                    style = TextStyle(color = textSecondary, fontSize = 10.sp),
                )
                Spacer(modifier = GlanceModifier.height(4.dp))
                Text(
                    text = lastTxn1,
                    style = TextStyle(color = textPrimary, fontSize = 11.sp),
                    maxLines = 1,
                )
                if (lastTxn2.isNotEmpty()) {
                    Text(
                        text = lastTxn2,
                        style = TextStyle(color = textPrimary, fontSize = 11.sp),
                        maxLines = 1,
                    )
                }
                if (lastTxn3.isNotEmpty()) {
                    Text(
                        text = lastTxn3,
                        style = TextStyle(color = textPrimary, fontSize = 11.sp),
                        maxLines = 1,
                    )
                }
            }
        }
    }
}
