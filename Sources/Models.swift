import Foundation
import SwiftUI

// MARK: - Curriculum
struct Curriculum: Codable { let modules: [ModuleInfo] }

struct ModuleInfo: Codable, Identifiable {
    let number: Int
    let titleEn: String
    let titleFa: String
    let parts: [PartInfo]
    var id: Int { number }
    var unitIds: [Int] { parts.flatMap { $0.units.map { $0.id } } }
}

struct PartInfo: Codable, Identifiable {
    let titleEn: String
    let titleFa: String
    let units: [UnitRef]
    var id: String { titleEn }
}

struct UnitRef: Codable, Identifiable {
    let id: Int
    let titleEn: String
    let titleFa: String
}

// MARK: - Unit content
struct UnitContentFile: Codable { let units: [UnitContent] }

struct UnitContent: Codable, Identifiable {
    let id: Int
    let overviewEn: String
    let overviewFa: String
    let keyTerms: [String]
    let sections: [LessonSection]
    let keyConcepts: [KeyConcept]?
}

// A richer key term: definition + sub-branches + examples (from the course book).
struct KeyConcept: Codable, Identifiable {
    let term: String
    let glossEn: String
    let glossFa: String
    let branches: [BiText]?
    let examples: [String]?
    var id: String { term }
}

struct LessonSection: Codable, Identifiable {
    let headingEn: String
    let headingFa: String
    let bodyEn: String
    let bodyFa: String
    let bullets: [BiText]?
    var id: String { headingEn }
}

struct BiText: Codable, Identifiable {
    let en: String
    let fa: String
    var id: String { en }
}

// MARK: - Glossary
struct GlossaryFile: Codable { let terms: [GlossaryTerm] }

struct GlossaryTerm: Codable, Identifiable {
    let term: String
    let pos: String
    let definitionEn: String
    let definitionFa: String
    let see: [String]
    var id: String { term }
}

// MARK: - Questions
struct QuestionFile: Codable { let questions: [Question] }

struct Question: Codable, Identifiable {
    let id: String
    let module: Int
    let unit: Int
    let type: String
    let stemEn: String
    let stemFa: String?
    let passage: String?
    let options: [AnswerOption]
    let answer: [String]
    let keyTerms: [String]
    let difficulty: Int
    let explanationEn: String
    let explanationFa: String
}

struct AnswerOption: Codable, Identifiable {
    let key: String
    let textEn: String
    let textFa: String?
    var id: String { key }
}

// MARK: - Mock tests
struct MockFile: Codable { let tests: [MockTest] }

struct MockTest: Codable, Identifiable {
    let id: String
    let titleEn: String
    let titleFa: String
    let module: Int
    let timeLimitMinutes: Int
    let questionIds: [String]
}

// MARK: - Extras (CLIL, Thornbury, CELTA toolkit)
struct ExtrasFile: Codable { let topics: [ExtraTopic] }
struct ExtraTopic: Codable, Identifiable {
    let titleEn: String
    let titleFa: String
    let sections: [LessonSection]
    var id: String { titleEn }
}

// MARK: - CELTA extension (organized course companion)
struct CeltaFile: Codable { let categories: [CeltaCategory]; let questions: [Question] }
struct CeltaCategory: Codable, Identifiable {
    let titleEn: String
    let titleFa: String
    let topics: [ExtraTopic]
    var id: String { titleEn }
}

// MARK: - Content store
@MainActor
final class ContentStore: ObservableObject {
    @Published var curriculum = Curriculum(modules: [])
    @Published var units: [Int: UnitContent] = [:]
    @Published var glossary: [GlossaryTerm] = []
    @Published var questions: [String: Question] = [:]
    @Published var questionsByUnit: [Int: [Question]] = [:]
    @Published var mockTests: [MockTest] = []
    @Published var extras: [ExtraTopic] = []
    @Published var celtaCategories: [CeltaCategory] = []
    @Published var celtaQuestions: [Question] = []

    init() { load() }

    private func decode<T: Decodable>(_ name: String, _ type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try? dec.decode(T.self, from: data)
    }

    func load() {
        if let c = decode("curriculum", Curriculum.self) { curriculum = c }
        if let u = decode("units", UnitContentFile.self) {
            for unit in u.units { units[unit.id] = unit }
        }
        if let g = decode("glossary", GlossaryFile.self) {
            glossary = g.terms.sorted { $0.term.lowercased() < $1.term.lowercased() }
        }
        if let q = decode("questions", QuestionFile.self) {
            for question in q.questions {
                questions[question.id] = question
                questionsByUnit[question.unit, default: []].append(question)
            }
        }
        if let m = decode("mocktests", MockFile.self) { mockTests = m.tests }
        if let e = decode("extras", ExtrasFile.self) { extras = e.topics }
        if let c = decode("celta", CeltaFile.self) {
            celtaCategories = c.categories
            celtaQuestions = c.questions
            for q in c.questions {
                questions[q.id] = q
                questionsByUnit[q.unit, default: []].append(q)
            }
        }
    }

    func unit(_ id: Int) -> UnitContent? { units[id] }
    func term(_ name: String) -> GlossaryTerm? { glossary.first { $0.term.lowercased() == name.lowercased() } }
    func questions(forUnit id: Int) -> [Question] { questionsByUnit[id] ?? [] }
    func questions(ids: [String]) -> [Question] { ids.compactMap { questions[$0] } }
    var allUnitRefs: [UnitRef] { curriculum.modules.flatMap { $0.parts.flatMap { $0.units } } }

    /// Practice questions whose key terms include this glossary term.
    func questions(forTerm name: String) -> [Question] {
        questions.values
            .filter { q in q.keyTerms.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
            .sorted { $0.id < $1.id }
    }
    /// A rich key-concept (branches + examples) for a term, if any unit defines one.
    func keyConcept(forTerm name: String) -> KeyConcept? {
        for u in units.values {
            if let kc = u.keyConcepts?.first(where: { $0.term.caseInsensitiveCompare(name) == .orderedSame }) { return kc }
        }
        return nil
    }
}

// MARK: - Progress store
final class ProgressStore: ObservableObject {
    @Published private(set) var completedUnits: Set<Int> = []
    @Published private(set) var correctQuestions: Set<String> = []
    @Published private(set) var seenQuestions: Set<String> = []
    @Published private(set) var wrongQuestions: Set<String> = []   // questions to review (got wrong, not yet re-mastered)

    private let kUnits = "completedUnits"
    private let kCorrect = "correctQuestions"
    private let kSeen = "seenQuestions"
    private let kWrong = "wrongQuestions"

    init() {
        let d = UserDefaults.standard
        completedUnits = Set((d.array(forKey: kUnits) as? [Int]) ?? [])
        correctQuestions = Set((d.array(forKey: kCorrect) as? [String]) ?? [])
        seenQuestions = Set((d.array(forKey: kSeen) as? [String]) ?? [])
        wrongQuestions = Set((d.array(forKey: kWrong) as? [String]) ?? [])
    }

    func markUnit(_ id: Int) { completedUnits.insert(id); save() }

    func record(question id: String, correct: Bool) {
        seenQuestions.insert(id)
        if correct { correctQuestions.insert(id); wrongQuestions.remove(id) }
        else { wrongQuestions.insert(id) }
        save()
    }

    func accuracy() -> Double {
        guard !seenQuestions.isEmpty else { return 0 }
        return Double(correctQuestions.count) / Double(seenQuestions.count)
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(Array(completedUnits), forKey: kUnits)
        d.set(Array(correctQuestions), forKey: kCorrect)
        d.set(Array(seenQuestions), forKey: kSeen)
        d.set(Array(wrongQuestions), forKey: kWrong)
    }
}

// MARK: - Helpers
func bandFor(_ accuracy: Double) -> String {
    switch accuracy {
    case 0.875...: return "Band 4"
    case 0.70..<0.875: return "Band 3"
    case 0.45..<0.70: return "Band 2"
    case let x where x > 0: return "Band 1"
    default: return "—"
    }
}
