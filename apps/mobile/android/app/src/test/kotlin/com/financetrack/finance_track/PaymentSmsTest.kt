package com.financetrack.finance_track

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PaymentSmsTest {
  @Test
  fun readsDebitsAndCredits() {
    assertEquals(
        PaymentText("500.00", false, "HDFCBK"),
        PaymentSms.read(
            "AX-HDFCBK-S",
            "Rs.500.00 debited from a/c **1234 on 18-10-26 to VPA ravi@okaxis. Avl bal Rs 12,000.50",
        ),
    )
    assertEquals(
        PaymentText("35,000", true, "SBIINB"),
        PaymentSms.read("VM-SBIINB", "Your A/c XX5678 is credited with INR 35,000 on 01-Nov. -SBI"),
    )
    assertEquals(
        PaymentText("5,000", false, "ICICIB"),
        PaymentSms.read("JM-ICICIB", "Loan EMI of Rs 5,000 debited from A/c XX11. Get great offers on our app"),
    )
  }

  @Test
  fun ignoresOtpsOffersPersonalNumbersAndMandates() {
    assertNull(PaymentSms.read("AD-HDFCBK", "123456 is your OTP for a payment of Rs 500. Do not share"))
    assertNull(PaymentSms.read("+919876543210", "Sent Rs 500 to you"))
    assertNull(PaymentSms.read("JD-AIRTEL", "Get a pre-approved loan of Rs 5,00,000 today"))
    assertNull(PaymentSms.read("AX-HDFCBK", "Rs 999 will be debited on 25-Oct for your Netflix mandate"))
    assertNull(PaymentSms.read("AX-HDFCBK", "Your card statement is ready, Rs 4,000 spent last month"))
  }
}
