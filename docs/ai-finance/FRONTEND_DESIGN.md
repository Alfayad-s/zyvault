# Frontend design

The ten screens are in `apps/mobile/lib/screens/intelligence_screen.dart`. The shell app bar opens them. Home, Activity, Money, Scheduled, and the existing Chat screen are not restyled.

Screens: dashboard, cash flow, safe-to-spend, health, advisor, purchase simulator, savings simulator, insights, unusual lines, advisor history.

They use the existing lime and ink colors and `formatMoney`. Each data screen has a progress line, an error message, and an empty state. Forecast chips switch 7, 15, 30, 60, and 90 days. Confirmed and estimated totals are separate labels. The advisor chips are English, Malayalam, and Hinglish.

The safe-to-spend screen can save an emergency reserve in rupees. The simulators say that nothing is written to accounts.

`apps/website` adds one feature card, a forecast mark, an FAQ, and a privacy sentence. It does not gain a signed-in area.
