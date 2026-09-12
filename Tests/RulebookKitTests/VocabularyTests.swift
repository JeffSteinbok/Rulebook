import Foundation
import Testing
@testable import RulebookKit

@Suite("Provider vocabulary")
struct VocabularyTests {

    @Test("Each provider uses its own noun for a rule")
    func providerNouns() {
        #expect(ProviderCatalog.outlook.ruleNoun == "rule")
        #expect(ProviderCatalog.outlook.folderNoun == "folder")
        #expect(ProviderCatalog.outlook.tagNoun == "category")

        // The local profile stays neutral rather than borrowing Outlook's nouns.
        #expect(ProviderCatalog.local.ruleNoun == "rule")
        #expect(ProviderCatalog.local.tagNoun == "label")
    }

    @Test("The same action is worded the way each product words it")
    func actionsAreWordedNatively() {
        let move = RuleAction.moveTo(.named("Reading"))
        #expect(ProviderCatalog.outlook.phrase(for: move) == "Move to ‘Reading’")

        let label = RuleAction.addLabel(.named("Bulky"))
        #expect(ProviderCatalog.outlook.phrase(for: label) == "Categorize as ‘Bulky’")

        #expect(ProviderCatalog.outlook.phrase(for: .markImportance(.high)) == "Mark with high importance")
    }

    @Test("The same condition is worded the way each product words it")
    func conditionsAreWordedNatively() {
        let subject = RuleCondition.subject(StringMatch("weekly"))
        #expect(ProviderCatalog.outlook.phrase(for: subject) == "Subject includes ‘weekly’")

        let body = RuleCondition.body(StringMatch("invoice"))
        #expect(ProviderCatalog.outlook.phrase(for: body) == "Message body includes ‘invoice’")

        #expect(ProviderCatalog.outlook.phrase(for: .addressed(.toMe)) == "I'm on the To line")

        #expect(ProviderCatalog.outlook.phrase(for: .hasLabels(["Reading"])) == "Categorized as ‘Reading’")
    }

    @Test("Sizes are shown in the units each product shows")
    func sizeUnits() {
        let size = RuleCondition.size(SizeConstraint(minimumBytes: 5_242_880))
        #expect(ProviderCatalog.outlook.phrase(for: size) == "Message size at least 5120 KB")
    }

    @Test("Field names suit a form label")
    func fieldNames() {
        #expect(ProviderCatalog.outlook.vocabulary.name(for: ConditionKind.subject) == "Subject includes")
    }

    @Test("A described rule reads as that provider's own summary")
    func describesNatively() throws {
        let rule = try Fixtures.decode([MailRule].self, from: "neutral-rules")[0]

        let outlook = ProviderCatalog.outlook.describe(rule)
        #expect(outlook.hasPrefix("Rule: Newsletters to Reading"))
        #expect(outlook.contains("Subject includes ‘weekly’"))
        #expect(outlook.contains("Move to ‘Reading’"))
        #expect(outlook.contains("Stop processing more rules"))
    }

    @Test("Only supported kinds are offered for a picker")
    func availableKindsFollowCapabilities() {
        #expect(ProviderCatalog.outlook.availableConditions.contains(.sensitivity))
        #expect(!ProviderCatalog.outlook.availableActions.contains(.archive))

        // The local profile has no limits, so it offers everything.
        #expect(ProviderCatalog.local.availableConditions.count == ConditionKind.allCases.count)
        #expect(ProviderCatalog.local.availableActions.count == ActionKind.allCases.count)
    }

    @Test("Provider names people actually type resolve", arguments: [
        ("outlook", ProviderID.microsoft), ("m365", .microsoft), ("microsoft", .microsoft),
        ("local", .local), ("offline", .local),
    ])
    func nameResolution(name: String, expected: ProviderID) {
        #expect(ProviderCatalog.profile(named: name)?.id == expected)
    }

    @Test("An unknown provider name resolves to nothing")
    func unknownProviderName() {
        #expect(ProviderCatalog.profile(named: "yahoo") == nil)
    }
}
