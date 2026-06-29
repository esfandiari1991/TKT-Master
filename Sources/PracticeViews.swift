import SwiftUI

// MARK: - Practice (per-unit)
struct PracticeView: View {
    @EnvironmentObject var progress: ProgressStore
    @AppStorage("showFa") private var showFa = false
    let questions: [Question]
    @State private var idx = 0
    @State private var chosen: String? = nil
    @State private var revealed = false

    var body: some View {
        if questions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle").font(.system(size: 40)).foregroundStyle(Theme.orange.opacity(0.7))
                Text("Practice questions for this unit are being added.").font(.title3)
                FaText(text: "سؤال‌های تمرینی این یونیت در حال افزوده‌شدن است.")
            }
            .frame(maxWidth: .infinity).padding(.vertical, 50).card()
        } else {
            let q = questions[min(idx, questions.count - 1)]
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Question \(idx + 1) of \(questions.count)").font(.callout.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    DifficultyBadge(level: q.difficulty)
                }
                QuestionCard(q: q, chosen: $chosen, revealed: $revealed, showFa: showFa)
                    .id(q.id)
                HStack {
                    if !revealed {
                        Button("Check answer") {
                            let correct = q.answer.contains(chosen ?? "")
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { revealed = true }
                            progress.record(question: q.id, correct: correct)
                            correct ? SFX.correct() : SFX.wrong()
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.orange)
                        .disabled(chosen == nil)
                    } else {
                        Button(idx + 1 < questions.count ? "Next question" : "Restart") {
                            withAnimation { if idx + 1 < questions.count { idx += 1 } else { idx = 0 }; chosen = nil; revealed = false }
                            SFX.tap()
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.orange)
                    }
                }
                .font(.body.weight(.semibold))
            }
        }
    }
}

// MARK: - Reusable question card
struct QuestionCard: View {
    let q: Question
    @Binding var chosen: String?
    @Binding var revealed: Bool
    let showFa: Bool

    var isCorrectChoice: Bool { q.answer.contains(chosen ?? "") }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let p = q.passage, !p.isEmpty {
                Text(p).font(.body).italic()
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.amber.opacity(0.12)))
            }
            Text(q.stemEn).font(.serif(20, .semibold))
            if showFa, let s = q.stemFa { FaText(text: s) }

            VStack(spacing: 10) {
                ForEach(q.options) { opt in
                    OptionRow(opt: opt,
                              correct: q.answer.contains(opt.key),
                              picked: chosen == opt.key,
                              revealed: revealed,
                              showFa: showFa) {
                        if !revealed { withAnimation(.easeOut(duration: 0.15)) { chosen = opt.key }; SFX.tap() }
                    }
                }
            }

            if revealed { explanationView.transition(.opacity.combined(with: .move(edge: .top))) }
        }
        .card()
    }

    var explanationView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Label(isCorrectChoice ? "Correct!" : "Not quite — here's why",
                  systemImage: isCorrectChoice ? "checkmark.seal.fill" : "lightbulb.fill")
                .font(.serif(18)).foregroundStyle(isCorrectChoice ? .green : Theme.orangeDeep)
                .scaleEffect(revealed ? 1 : 0.9)
            Text(q.explanationEn).font(.title3).lineSpacing(4)
            if showFa { FaText(text: q.explanationFa) }
            if !q.keyTerms.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill").font(.caption).foregroundStyle(Theme.orange)
                    Text(q.keyTerms.joined(separator: " · ")).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Option row (soft hover + press feel)
struct OptionRow: View {
    let opt: AnswerOption
    let correct: Bool
    let picked: Bool
    let revealed: Bool
    let showFa: Bool
    let onTap: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().fill(picked ? AnyShapeStyle(Theme.moduleGradient(1)) : AnyShapeStyle(Color.primary.opacity(0.10)))
                Text(opt.key).font(.title3.weight(.bold)).foregroundStyle(picked ? .white : .primary)
            }
            .frame(width: 38, height: 38)
            .shadow(color: picked ? Theme.orange.opacity(0.4) : .clear, radius: 5, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(opt.textEn).font(.title3)
                if showFa, let f = opt.textFa, f != opt.textEn { PersianText(text: f) }
            }
            Spacer()
            SpeakButton(text: opt.textEn)
            if revealed && correct { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title) }
            if revealed && picked && !correct { Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.title) }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(tint)
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(border, lineWidth: 2))
        .scaleEffect(hover && !revealed ? 1.015 : 1.0)
        .shadow(color: (hover && !revealed) ? Theme.orange.opacity(0.22) : Color.black.opacity(0.07),
                radius: (hover && !revealed) ? 13 : 5, y: (hover && !revealed) ? 6 : 2)
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .onTapGesture { if !revealed { onTap() } }
        .onHover { hover = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: revealed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: picked)
    }

    var tint: Color {
        if revealed && correct { return Color.green.opacity(0.18) }
        if revealed && picked && !correct { return Color.red.opacity(0.14) }
        if picked { return Theme.orange.opacity(0.14) }
        return Color.clear
    }
    var border: Color {
        if revealed && correct { return .green.opacity(0.75) }
        if revealed && picked && !correct { return .red.opacity(0.65) }
        if picked { return Theme.orange }
        if hover { return Theme.orange.opacity(0.5) }
        return Color.primary.opacity(0.12)
    }
}

// MARK: - Daily micro-learning review (adaptive)
struct ReviewSheet: View {
    let questions: [Question]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Daily Review", systemImage: "brain.head.profile").font(.serif(24)).foregroundStyle(Theme.orangeDeep)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.bordered).tint(Theme.orange)
            }
            if questions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 42)).foregroundStyle(.green)
                    Text("Nothing to review right now.").font(.title3.weight(.semibold))
                    Text("Answer practice questions — anything you get wrong shows up here for spaced review.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                Text("Smart review of the questions you found hardest — a short, focused session.")
                    .foregroundStyle(.secondary)
                ScrollView { PracticeView(questions: questions).padding(.top, 4) }
            }
        }
        .padding(26)
        .frame(width: 720, height: 640)
        .background(PaperBackground())
    }
}

// MARK: - Glossary
struct GlossaryView: View {
    @EnvironmentObject var store: ContentStore
    @AppStorage("showFa") private var showFa = false
    @State private var query = ""
    @State private var selected: GlossaryTerm?

    var filtered: [GlossaryTerm] {
        guard !query.isEmpty else { return store.glossary }
        return store.glossary.filter {
            $0.term.localizedCaseInsensitiveContains(query) ||
            $0.definitionEn.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Glossary").font(.serif(30))
                Text("\(store.glossary.count) terms").font(.callout).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 30).padding(.top, 26).padding(.bottom, 10)

            List {
                ForEach(filtered) { t in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(t.term).font(.serif(17))
                            if !t.pos.isEmpty { Text(t.pos).font(.caption).foregroundStyle(Theme.orange) }
                            Spacer()
                            SpeakButton(text: t.term)
                            Image(systemName: "chevron.right.circle").font(.body).foregroundStyle(Theme.orange.opacity(0.7))
                        }
                        Text(t.definitionEn).font(.callout).lineLimit(2)
                        if !t.see.isEmpty {
                            Text("See: " + t.see.joined(separator: ", ")).font(.footnote).foregroundStyle(Theme.orange)
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { selected = t; SFX.tap() }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $query, prompt: "Search terms…")
        }
        .sheet(item: $selected) { t in
            GlossaryDetailView(term: t).environmentObject(store)
        }
    }
}

// MARK: - Glossary term detail (full mini-lesson: definition, types, examples, sample questions)
struct GlossaryDetailView: View {
    @State private var current: GlossaryTerm
    @EnvironmentObject var store: ContentStore
    @AppStorage("showFa") private var showFa = false
    @Environment(\.dismiss) private var dismiss

    init(term: GlossaryTerm) { _current = State(initialValue: term) }

    var related: [Question] { store.questions(forTerm: current.term) }
    var concept: KeyConcept? { store.keyConcept(forTerm: current.term) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(current.term).font(.serif(28))
                if !current.pos.isEmpty { Text(current.pos).font(.callout).foregroundStyle(.secondary) }
                SpeakButton(text: current.term, font: .title)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.bordered).tint(Theme.orange)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Definition", systemImage: "text.alignleft").font(.serif(17)).foregroundStyle(Theme.orange)
                        Text(current.definitionEn).font(.title3)
                        if showFa && !current.definitionFa.isEmpty { FaText(text: current.definitionFa) }
                    }.card().frame(maxWidth: .infinity, alignment: .leading)

                    if let c = concept, let branches = c.branches, !branches.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Types & sub-branches", systemImage: "list.bullet.indent").font(.serif(17)).foregroundStyle(Theme.orange)
                            ForEach(branches) { b in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "chevron.right.circle.fill").font(.caption).foregroundStyle(Theme.orange).padding(.top, 4)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(b.en).font(.body)
                                        if showFa { PersianText(text: b.fa) }
                                    }
                                }
                            }
                        }.card().frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let c = concept, let examples = c.examples, !examples.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Examples", systemImage: "quote.opening").font(.serif(17)).foregroundStyle(Theme.orange)
                            ForEach(examples, id: \.self) { ex in
                                HStack { Text(ex).font(.title3); Spacer(); SpeakButton(text: ex) }
                            }
                        }.card().frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !current.see.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("See also", systemImage: "arrow.triangle.branch").font(.serif(17)).foregroundStyle(Theme.orange)
                            FlowChips(items: current.see) { ref in
                                if let t = store.term(ref) {
                                    withAnimation { current = t }; SFX.tap()
                                }
                            }
                        }.card().frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !related.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Practice on this term", systemImage: "questionmark.circle.fill").font(.serif(17)).foregroundStyle(Theme.orange)
                            ForEach(related) { q in miniQuestion(q) }
                        }.card().frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 780, height: 700)
        .background(PaperBackground())
    }

    func miniQuestion(_ q: Question) -> some View {
        let ans = q.options.filter { q.answer.contains($0.key) }.map { "\($0.key). \($0.textEn)" }.joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 6) {
            Text(q.stemEn).font(.body.weight(.semibold))
            Text("Answer: \(ans)").font(.callout).foregroundStyle(.green)
            Text(q.explanationEn).font(.callout).foregroundStyle(.secondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }
}

// Tappable cross-reference chips (horizontal, scrollable).
struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { it in
                    Button { onTap(it) } label: {
                        HStack(spacing: 5) {
                            Text(it).font(.callout.weight(.medium))
                            Image(systemName: "arrow.up.right").font(.caption2)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Theme.orange.opacity(0.14)))
                        .overlay(Capsule().stroke(Theme.orange.opacity(0.4), lineWidth: 1))
                        .foregroundStyle(Theme.orangeDeep)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Mock tests list
struct MockListView: View {
    @EnvironmentObject var store: ContentStore
    @AppStorage("showFa") private var showFa = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.heroGradient)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mock Tests").font(.serif(34)).foregroundStyle(.white)
                            Text("Timed, exam-style tests with full explanations and a predicted band.")
                                .font(.title3).foregroundStyle(.white.opacity(0.95))
                            if showFa { faWhite("آزمون‌های زمان‌دار و واقع‌گرایانه با توضیح کامل و باند پیش‌بینی‌شده.") }
                        }
                        .padding(26).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .appear(0)

                    ForEach(Array(store.mockTests.enumerated()), id: \.element.id) { i, t in
                        NavigationLink(value: t.id) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t.titleEn).font(.serif(19))
                                    if showFa {
                                        PersianText(text: t.titleFa, font: .callout)
                                    }
                                    Text("\(t.questionIds.count) questions · \(t.timeLimitMinutes) min")
                                        .font(.callout).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill").font(.system(size: 34)).foregroundStyle(Theme.orange)
                            }
                            .card().frame(maxWidth: .infinity, alignment: .leading).hoverLift()
                        }
                        .buttonStyle(.plain)
                        .appear(0.07 * Double(i + 1))
                    }
                }
                .padding(30).frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationDestination(for: String.self) { id in
                if let t = store.mockTests.first(where: { $0.id == id }) { MockRunnerView(test: t) }
            }
        }
    }

    func faWhite(_ s: String) -> some View {
        Text(s).environment(\.layoutDirection, .rightToLeft)
            .multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
            .foregroundStyle(.white.opacity(0.92))
    }
}

// MARK: - Mock test runner
struct MockRunnerView: View {
    @EnvironmentObject var store: ContentStore
    @EnvironmentObject var progress: ProgressStore
    @AppStorage("showFa") private var showFa = false
    let test: MockTest

    @State private var idx = 0
    @State private var chosen: String? = nil
    @State private var revealed = false
    @State private var answers: [String: String] = [:]
    @State private var finished = false
    @State private var remaining = 0

    let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var qs: [Question] { store.questions(ids: test.questionIds) }
    var timeStr: String { String(format: "%d:%02d", remaining / 60, remaining % 60) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if finished || qs.isEmpty { results } else { runner }
            }
            .padding(30).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { if remaining == 0 { remaining = test.timeLimitMinutes * 60 } }
        .onReceive(ticker) { _ in
            guard !finished else { return }
            if remaining > 0 { remaining -= 1 } else { withAnimation { finished = true } }
        }
    }

    var runner: some View {
        let q = qs[min(idx, qs.count - 1)]
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(test.titleEn).font(.serif(20))
                Spacer()
                Label(timeStr, systemImage: "clock.fill").monospacedDigit()
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(remaining < 60 ? .red : Theme.orange)
            }
            ProgressView(value: Double(idx), total: Double(max(qs.count, 1))).tint(Theme.orange)
            QuestionCard(q: q, chosen: $chosen, revealed: $revealed, showFa: showFa).id(q.id)
            HStack {
                if !revealed {
                    Button("Check") {
                        let correct = q.answer.contains(chosen ?? "")
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { revealed = true }
                        answers[q.id] = chosen
                        progress.record(question: q.id, correct: correct)
                        correct ? SFX.correct() : SFX.wrong()
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.orange)
                    .disabled(chosen == nil)
                } else {
                    Button(idx + 1 < qs.count ? "Next" : "See results") {
                        withAnimation {
                            if idx + 1 < qs.count { idx += 1; chosen = nil; revealed = false }
                            else { finished = true }
                        }
                        SFX.tap()
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.orange)
                }
            }
            .font(.body.weight(.semibold))
        }
    }

    var results: some View {
        let correct = qs.filter { answers[$0.id] != nil && $0.answer.contains(answers[$0.id]!) }.count
        let total = max(qs.count, 1)
        let pct = Double(correct) / Double(total)
        return VStack(spacing: 16) {
            Text("Results").font(.serif(32))
            RingProgress(value: pct, color: Theme.orange, size: 130)
            Text("\(correct) / \(qs.count) correct").font(.title3.weight(.semibold))
            Text(bandFor(pct)).font(.serif(22)).foregroundStyle(Theme.orange)
            if showFa { FaText(text: "درصد صحیح و باند پیش‌بینی‌شده بر اساس همین آزمون.") }
        }
        .frame(maxWidth: .infinity).card(padding: 30).appear(0)
    }
}
