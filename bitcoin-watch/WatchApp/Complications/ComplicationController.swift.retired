import ClockKit

// ClockKit complication data source.
// Called by watchOS whenever it needs to render the complication or
// extend its timeline. WatchPriceService.reloadComplications() triggers
// this fresh whenever a new price arrives (from iPhone push or direct fetch).
class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(for complication: CLKComplication,
                                  withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        handler(entry(for: complication, date: Date()))
    }

    func getTimelineEntries(for complication: CLKComplication,
                             after date: Date,
                             limit: Int,
                             withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // We don't pre-schedule future entries — price is unpredictable.
        // Each real price push triggers a full reload instead.
        handler(nil)
    }

    // No end date — always keep complication active
    func getTimelineEndDate(for complication: CLKComplication,
                             withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getPrivacyBehavior(for complication: CLKComplication,
                             withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication,
                                       withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        handler(template(for: complication, usd: 65000))
    }

    // MARK: - Helpers

    private func entry(for complication: CLKComplication, date: Date) -> CLKComplicationTimelineEntry? {
        let usd = UserDefaults.shared.loadPrice()?.usd ?? 0
        guard let tmpl = template(for: complication, usd: usd) else { return nil }
        return CLKComplicationTimelineEntry(date: date, complicationTemplate: tmpl)
    }

    private func template(for complication: CLKComplication, usd: Double) -> CLKComplicationTemplate? {
        let price = BitcoinPrice(usd: usd, timestamp: Date())
        let shortText = CLKSimpleTextProvider(text: price.shortFormatted)
        let btcLabel  = CLKSimpleTextProvider(text: "BTC")
        let fullText  = CLKSimpleTextProvider(text: price.formatted)

        switch complication.family {
        case .modularSmall:
            let t = CLKComplicationTemplateModularSmallStackText()
            t.line1TextProvider = btcLabel
            t.line2TextProvider = shortText
            return t

        case .modularLarge:
            let t = CLKComplicationTemplateModularLargeStandardBody()
            t.headerTextProvider = btcLabel
            t.body1TextProvider = fullText
            return t

        case .utilitarianSmall, .utilitarianSmallFlat:
            let t = CLKComplicationTemplateUtilitarianSmallFlat()
            t.textProvider = shortText
            return t

        case .utilitarianLarge:
            let t = CLKComplicationTemplateUtilitarianLargeFlat()
            t.textProvider = CLKSimpleTextProvider(text: "BTC \(price.shortFormatted)")
            return t

        case .circularSmall:
            let t = CLKComplicationTemplateCircularSmallStackText()
            t.line1TextProvider = btcLabel
            t.line2TextProvider = shortText
            return t

        case .extraLarge:
            let t = CLKComplicationTemplateExtraLargeStackText()
            t.line1TextProvider = btcLabel
            t.line2TextProvider = shortText
            return t

        case .graphicCorner:
            let t = CLKComplicationTemplateGraphicCornerStackText()
            t.outerTextProvider = btcLabel
            t.innerTextProvider = shortText
            return t

        case .graphicBezel:
            let circle = CLKComplicationTemplateGraphicCircularStackText()
            circle.line1TextProvider = btcLabel
            circle.line2TextProvider = shortText
            let t = CLKComplicationTemplateGraphicBezelCircularText()
            t.circularTemplate = circle
            t.textProvider = fullText
            return t

        case .graphicCircular:
            let t = CLKComplicationTemplateGraphicCircularStackText()
            t.line1TextProvider = btcLabel
            t.line2TextProvider = shortText
            return t

        case .graphicRectangular:
            let t = CLKComplicationTemplateGraphicRectangularStandardBody()
            t.headerTextProvider = btcLabel
            t.body1TextProvider = fullText
            return t

        case .graphicExtraLarge:
            let t = CLKComplicationTemplateGraphicExtraLargeCircularStackText()
            t.line1TextProvider = btcLabel
            t.line2TextProvider = shortText
            return t

        @unknown default:
            return nil
        }
    }
}
