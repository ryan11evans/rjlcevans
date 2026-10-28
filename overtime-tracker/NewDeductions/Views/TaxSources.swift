import Foundation

struct TaxSource: Identifiable {
    var id: String { url.absoluteString }
    var title: String
    var detail: String
    var url: URL
}

/// Citations from the build plan (§1 overtime, §7 car loan). Opening one hands the URL to Safari; the app does not fetch it.
enum TaxSources {
    static let overtime: [TaxSource] = [
        source(
            "IRS: One Big Beautiful Bill Act deductions",
            "FS-2025-03. Tax years 2025–2028 and who can claim.",
            "https://www.irs.gov/newsroom/one-big-beautiful-bill-act-tax-deductions-for-working-americans-and-seniors"
        ),
        source(
            "26 U.S.C. §225",
            "The overtime deduction statute, including the cap and phase-out.",
            "https://uscode.house.gov/us/usc/119-124/t26/s225/"
        ),
        source(
            "IRS: No tax on overtime",
            "What qualifies, the cap, and Schedule 1-A.",
            "https://www.irs.gov/newsroom/what-to-know-about-the-no-tax-on-overtime-deduction"
        ),
        source(
            "IRS Notice 2025-69",
            "2025 transition: workers can compute qualified overtime when the W-2 does not list it. PDF.",
            "https://www.irs.gov/pub/irs-drop/n-25-69.pdf"
        ),
        source(
            "IRS FS-2026-13",
            "W-2 Box 12 code TT for 2026 and later. PDF.",
            "https://www.irs.gov/pub/taxpros/fs-2026-13.pdf"
        ),
        source(
            "ADP: Qualified overtime and tips",
            "Overtime the FLSA does not require is not qualified overtime.",
            "https://www.adp.com/spark/articles/2026/01/federal-tax-deductions-for-qualified-overtime-and-tips-what-employers-need-to-know.aspx"
        ),
    ]

    static let carLoan: [TaxSource] = [
        source(
            "IRS: Understanding your CP321N notice",
            "VIN reporting, tax years, and that itemizing is not required.",
            "https://www.irs.gov/individuals/understanding-your-cp321n-notice"
        ),
        source(
            "IRS Publication 6126",
            "Which vehicles qualify, and refinance treatment. PDF.",
            "https://www.irs.gov/pub/irs-pdf/p6126.pdf"
        ),
        source(
            "Treasury Decision 10054",
            "Final regulations: $10,000 cap and the phase-out that rounds partial thousands up.",
            "https://www.govinfo.gov/content/pkg/FR-2026-09-08/html/2026-18219.htm"
        ),
    ]

    private static func source(_ title: String, _ detail: String, _ url: String) -> TaxSource {
        TaxSource(title: title, detail: detail, url: URL(string: url)!)
    }
}
