import SwiftUI

// Small helper: white Persian text for use on coloured headers.
private struct FaWhite: View {
    let text: String
    var body: some View {
        Text(text)
            .environment(\.layoutDirection, .rightToLeft)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .foregroundStyle(.white.opacity(0.92))
    }
}

// MARK: - Dashboard
struct DashboardView: View {
    @EnvironmentObject var store: ContentStore
    @EnvironmentObject var progress: ProgressStore
    @AppStorage("showFa") private var showFa = false
    @State private var showReview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero.appear(0)

                Text("Your modules").font(.serif(22)).appear(0.05)
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(store.curriculum.modules.enumerated()), id: \.element.id) { i, m in
                        moduleCard(m).appear(0.08 * Double(i + 1))
                    }
                }

                Text("Your progress").font(.serif(22)).appear(0.3)
                HStack(spacing: 18) {
                    stat("Units studied", "\(progress.completedUnits.count)/33", "book.fill")
                    stat("Correct", "\(progress.correctQuestions.count)", "checkmark.circle.fill")
                    stat("Accuracy", "\(Int((progress.accuracy() * 100).rounded()))%", "target")
                    stat("Predicted band", bandFor(progress.accuracy()), "rosette")
                }
                .appear(0.36)

                smartReviewCard.appear(0.42)

                Text("TKT Master is an independent study app built on the publicly available Cambridge English TKT syllabus and glossary. It is not affiliated with, endorsed by, or sponsored by Cambridge University Press & Assessment.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .appear(0.5)
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showReview) {
            ReviewSheet(questions: reviewSet)
                .environmentObject(progress)
                .environmentObject(store)
        }
    }

    var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.heroGradient)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TKT Master").font(.serif(42)).foregroundStyle(.white)
                    Text("Complete, offline preparation for the Cambridge TKT — Modules 1, 2 & 3.")
                        .font(.title3).foregroundStyle(.white.opacity(0.95))
                    if showFa { FaWhite(text: "آمادگی کامل و آفلاین برای آزمون TKT کمبریج — ماژول‌های ۱، ۲ و ۳.") }
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.circle.fill")
                        Text("An EduPocket project · EduPocket.org").font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.92)).padding(.top, 4)
                }
                Spacer()
                FloatingMotif()
                    .padding(20)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: Theme.orange.opacity(0.25), radius: 18, x: 0, y: 10)
    }

    func moduleCard(_ m: ModuleInfo) -> some View {
        let ids = m.unitIds
        let done = ids.filter { progress.completedUnits.contains($0) }.count
        let frac = ids.isEmpty ? 0 : Double(done) / Double(ids.count)
        let color = Theme.moduleColor(m.number)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text("Module \(m.number)").font(.serif(22)).foregroundStyle(color)
                Spacer()
                RingProgress(value: frac, color: color, size: 56)
            }
            Text(m.titleEn)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(3)
                .frame(height: 56, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(done) / \(ids.count) units").font(.footnote.weight(.medium)).foregroundStyle(.secondary)
        }
        .card()
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverLift()
    }

    func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.orange)
            Text(value).font(.serif(26)).foregroundStyle(.primary)
            Text(title).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card()
        .hoverLift()
    }

    // MARK: Adaptive review (offline memory of strengths & weaknesses)
    private var attempted: [Question] { store.questions.values.filter { progress.seenQuestions.contains($0.id) } }

    private func fraction(_ m: ModuleInfo) -> Double {
        let ids = m.unitIds
        let done = ids.filter { progress.completedUnits.contains($0) }.count
        return ids.isEmpty ? 0 : Double(done) / Double(ids.count)
    }

    private var recommendedModule: Int {
        var best = 0
        var bestScore = Double.greatestFiniteMagnitude
        for m in store.curriculum.modules {
            let qs = attempted.filter { $0.module == m.number }
            guard !qs.isEmpty else { continue }
            let acc = Double(qs.filter { progress.correctQuestions.contains($0.id) }.count) / Double(qs.count)
            if acc < bestScore { bestScore = acc; best = m.number }
        }
        if best == 0 { return store.curriculum.modules.min(by: { fraction($0) < fraction($1) })?.number ?? 1 }
        return best
    }

    private var reviewSet: [Question] {
        let wrong = store.questions.values.filter { progress.wrongQuestions.contains($0.id) }
        if !wrong.isEmpty { return Array(wrong.prefix(8)) }
        let mod = recommendedModule
        return Array(store.questions.values.filter { $0.module == mod }.prefix(6))
    }

    private var recommendationText: String {
        if !progress.wrongQuestions.isEmpty {
            return "You have \(progress.wrongQuestions.count) question(s) to revisit. A short, focused session strengthens your weak spots."
        }
        if progress.seenQuestions.isEmpty {
            return "Start with Module \(recommendedModule). The app remembers what you find hard and builds your review automatically."
        }
        return "Great accuracy so far — keep momentum with Module \(recommendedModule)."
    }

    private var smartReviewCard: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Smart Review", systemImage: "brain.head.profile").font(.serif(20)).foregroundStyle(Theme.orangeDeep)
                Text(recommendationText).font(.title3).foregroundStyle(.primary.opacity(0.85))
            }
            Spacer(minLength: 12)
            Button { showReview = true; SFX.tap() } label: {
                Label("Start review", systemImage: "play.fill").font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent).tint(Theme.orange).hoverLift()
        }
        .card(padding: 22)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Module browser
struct ModuleView: View {
    @EnvironmentObject var store: ContentStore
    @EnvironmentObject var progress: ProgressStore
    @AppStorage("showFa") private var showFa = false
    let moduleNumber: Int

    var module: ModuleInfo? { store.curriculum.modules.first { $0.number == moduleNumber } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let m = module {
                    VStack(alignment: .leading, spacing: 22) {
                        header(m).appear(0)
                        ForEach(Array(m.parts.enumerated()), id: \.element.id) { i, part in
                            partCard(part, color: Theme.moduleColor(m.number)).appear(0.08 * Double(i + 1))
                        }
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationDestination(for: Int.self) { uid in UnitDetailView(unitId: uid) }
        }
    }

    func header(_ m: ModuleInfo) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.moduleGradient(m.number))
            VStack(alignment: .leading, spacing: 6) {
                Text("Module \(m.number)").font(.serif(34)).foregroundStyle(.white)
                Text(m.titleEn).font(.title3).foregroundStyle(.white.opacity(0.95))
                if showFa { FaWhite(text: m.titleFa) }
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .shadow(color: Theme.moduleColor(m.number).opacity(0.25), radius: 14, x: 0, y: 8)
    }

    func partCard(_ part: PartInfo, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(part.titleEn).font(.serif(19))
            if showFa {
                PersianText(text: part.titleFa, font: .callout)
            }
            VStack(spacing: 6) {
                ForEach(part.units) { u in
                    NavigationLink(value: u.id) { unitRow(u, color: color) }
                        .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    func unitRow(_ u: UnitRef, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.16))
                Text("\(u.id)").font(.headline).foregroundStyle(color)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(u.titleEn).font(.body.weight(.semibold))
                if showFa {
                    PersianText(text: u.titleFa, font: .callout)
                }
            }
            Spacer()
            if progress.completedUnits.contains(u.id) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            }
            Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.02)))
        .contentShape(Rectangle())
        .hoverLift()
    }
}

// MARK: - Unit detail
struct UnitDetailView: View {
    @EnvironmentObject var store: ContentStore
    @EnvironmentObject var progress: ProgressStore
    @AppStorage("showFa") private var showFa = false
    let unitId: Int
    @State private var tab = 0

    var ref: UnitRef? { store.allUnitRefs.first { $0.id == unitId } }
    var content: UnitContent? { store.unit(unitId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let r = ref {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Unit \(r.id)").font(.callout.weight(.bold)).foregroundStyle(Theme.orange)
                    Text(r.titleEn).font(.serif(30))
                    if showFa {
                        PersianText(text: r.titleFa, font: .title3)
                    }
                }
                .padding(.horizontal, 30).padding(.top, 26).padding(.bottom, 12)
            }

            Picker("", selection: $tab) {
                Text("Lesson").tag(0)
                Text("Key Terms").tag(1)
                Text("Practice").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 30)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                Group {
                    if tab == 0 { lessonTab }
                    else if tab == 1 { keyTermsTab }
                    else { PracticeView(questions: store.questions(forUnit: unitId)) }
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(tab)
                .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.25), value: tab)
        }
    }

    var lessonTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let c = content {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Overview", systemImage: "text.alignleft").font(.serif(20)).foregroundStyle(Theme.orange)
                    Text(c.overviewEn).font(.title3).lineSpacing(5)
                    if showFa { FaText(text: c.overviewFa) }
                    if !c.keyTerms.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(c.keyTerms, id: \.self) { name in
                                    TermChip(term: name, definition: store.term(name)?.definitionEn ?? "")
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .card().appear(0)

                ForEach(Array(c.sections.enumerated()), id: \.element.id) { i, s in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(s.headingEn).font(.serif(18))
                        if showFa {
                            PersianText(text: s.headingFa, font: .subheadline)
                        }
                        Text(s.bodyEn).font(.title3).lineSpacing(5)
                        if showFa { FaText(text: s.bodyFa) }
                        if let bullets = s.bullets {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(bullets) { b in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(Theme.orange).padding(.top, 7)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(b.en).font(.body)
                                            if showFa { FaText(text: b.fa) }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .card().appear(0.05 * Double(i + 1))
                }

                if c.sections.isEmpty {
                    Label("A full step-by-step lesson for this unit is being added. The overview and key terms already cover the core ideas you need.", systemImage: "hammer.fill")
                        .font(.callout).foregroundStyle(.secondary).card()
                }

                Button {
                    progress.markUnit(unitId); SFX.correct()
                } label: {
                    Label(progress.completedUnits.contains(unitId) ? "Marked as studied" : "Mark unit as studied",
                          systemImage: progress.completedUnits.contains(unitId) ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent).tint(Theme.orange)
                .disabled(progress.completedUnits.contains(unitId))
                .appear(0.2)
            }
        }
    }

    var keyTermsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let c = content {
                if let concepts = c.keyConcepts, !concepts.isEmpty {
                    ForEach(Array(concepts.enumerated()), id: \.element.id) { i, kc in
                        conceptCard(kc).appear(0.04 * Double(i + 1))
                    }
                }
                let shown = Set((c.keyConcepts ?? []).map { $0.term.lowercased() })
                let rest = c.keyTerms.filter { !shown.contains($0.lowercased()) }
                ForEach(Array(rest.enumerated()), id: \.offset) { i, name in
                    termCard(name).appear(0.04 * Double(i + 1))
                }
            }
        }
    }

    func conceptCard(_ kc: KeyConcept) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(kc.term).font(.serif(19)).foregroundStyle(Theme.orangeDeep)
                SpeakButton(text: kc.term)
                Spacer()
            }
            Text(kc.glossEn).font(.callout)
            if showFa { FaText(text: kc.glossFa) }
            if let branches = kc.branches, !branches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(branches) { b in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "chevron.right.circle.fill").font(.caption).foregroundStyle(Theme.orange).padding(.top, 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.en).font(.callout)
                                if showFa { PersianText(text: b.fa) }
                            }
                        }
                    }
                }.padding(.top, 2)
            }
            if let examples = kc.examples, !examples.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening").font(.caption).foregroundStyle(Theme.orange)
                    Text(examples.joined(separator: "  ·  ")).font(.callout).foregroundStyle(.secondary)
                    SpeakButton(text: examples.joined(separator: ", "))
                    Spacer()
                }.padding(.top, 2)
            }
        }
        .card().frame(maxWidth: .infinity, alignment: .leading)
    }

    func termCard(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let t = store.term(name) {
                HStack(spacing: 8) {
                    Text(t.term).font(.serif(18))
                    if !t.pos.isEmpty { Text(t.pos).font(.caption).foregroundStyle(.secondary) }
                    SpeakButton(text: t.term)
                    Spacer()
                }
                Text(t.definitionEn).font(.callout)
                if showFa && !t.definitionFa.isEmpty { FaText(text: t.definitionFa) }
            } else {
                HStack(spacing: 8) { Text(name).font(.serif(18)); SpeakButton(text: name); Spacer() }
                Text("Definition is being added to the glossary.").font(.callout).foregroundStyle(.secondary)
            }
        }
        .card().frame(maxWidth: .infinity, alignment: .leading).hoverLift()
    }
}

// MARK: - CELTA extras
struct CeltaView: View {
    @EnvironmentObject var store: ContentStore
    @EnvironmentObject var progress: ProgressStore
    @AppStorage("showFa") private var showFa = false
    @State private var showQuiz = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.heroGradient)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CELTA Course — Trainee Companion").font(.serif(32)).foregroundStyle(.white)
                        Text("Everything for the CELTA: practical teaching skills, full lesson planning, language analysis (MFP), teaching-skills frameworks, assessment, and trainer expectations (ITI-style). Plus CLIL extras.")
                            .font(.title3).foregroundStyle(.white.opacity(0.95))
                        if showFa { FaWhite(text: "هرچه برای CELTA لازم داری: مهارت‌های عملیِ تدریس، نوشتنِ کاملِ طرح درس، تحلیلِ زبان (MFP)، چارچوب‌های مهارت، ارزیابی، و انتظاراتِ مربی (سبکِ ITI). به‌علاوهٔ مطالبِ CLIL.") }
                    }
                    .padding(26).frame(maxWidth: .infinity, alignment: .leading)
                }
                .appear(0)

                Button { showQuiz = true; SFX.tap() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checklist")
                        Text("Take the CELTA quiz  (\(store.celtaQuestions.count) Q)").font(.title3.weight(.semibold))
                        Spacer()
                        Image(systemName: "play.circle.fill").font(.title2)
                    }
                    .foregroundStyle(.white).padding(18)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.orange))
                    .shadow(color: Theme.orange.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(.plain).hoverLift().appear(0.05)

                ForEach(Array(store.celtaCategories.enumerated()), id: \.element.id) { i, cat in
                    categoryHeader(cat.titleEn, cat.titleFa).appear(0.06 * Double(i + 1))
                    ForEach(cat.topics) { topic in topicCard(topic) }
                }

                if !store.extras.isEmpty {
                    categoryHeader("CLIL & Teaching Extras", "مطالبِ تکمیلیِ CLIL و تدریس")
                    ForEach(store.extras) { topic in topicCard(topic) }
                }
            }
            .padding(30).frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showQuiz) {
            ReviewSheet(questions: store.celtaQuestions)
                .environmentObject(store).environmentObject(progress)
        }
    }

    func categoryHeader(_ en: String, _ faTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(en).font(.serif(24)).foregroundStyle(Theme.orangeDeep)
            if showFa { PersianText(text: faTitle, font: .title3) }
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func topicCard(_ topic: ExtraTopic) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill").foregroundStyle(Theme.orange)
                Text(topic.titleEn).font(.serif(22)).foregroundStyle(Theme.orangeDeep)
                Spacer()
            }
            if showFa { PersianText(text: topic.titleFa, font: .title3) }
            ForEach(topic.sections) { s in
                VStack(alignment: .leading, spacing: 8) {
                    Text(s.headingEn).font(.serif(17))
                    Text(s.bodyEn).font(.body)
                    if showFa { FaText(text: s.bodyFa) }
                    if let bullets = s.bullets {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(bullets) { b in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(Theme.orange).padding(.top, 7)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(b.en).font(.callout)
                                        if showFa { PersianText(text: b.fa) }
                                    }
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .card().frame(maxWidth: .infinity, alignment: .leading)
    }
}
