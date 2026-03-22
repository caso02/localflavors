import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var animateContent = false
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var locationPulse = false
    private let locationManager = CLLocationManager()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color.orange.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    locationPage.tag(1)
                    scanPage.tag(2)
                    resultsPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onChange(of: currentPage) { _, _ in
            animateContent = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animateContent = true
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animateContent = true
                }
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated hero
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .scaleEffect(animateContent ? 1.0 : 0.5)

                Circle()
                    .fill(.orange.opacity(0.06))
                    .frame(width: 280, height: 280)
                    .scaleEffect(animateContent ? 1.0 : 0.3)

                Image(systemName: "fork.knife")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.orange)
                    .scaleEffect(animateContent ? 1.0 : 0.3)
                    .opacity(animateContent ? 1 : 0)

                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: [14, 10, 12, 9, 11][i]))
                        .foregroundStyle(.yellow)
                        .offset(
                            x: [80, -70, 95, -85, 60][i] * (animateContent ? 1 : 0.2),
                            y: [-60, -40, 20, 50, -80][i] * (animateContent ? 1 : 0.2)
                        )
                        .opacity(animateContent ? [0.9, 0.7, 0.8, 0.6, 0.75][i] : 0)
                        .animation(
                            .spring(response: 0.8, dampingFraction: 0.5).delay(Double(i) * 0.1),
                            value: animateContent
                        )
                }
            }
            .frame(height: 300)

            VStack(spacing: 14) {
                Text(String(localized: "onboarding.welcome.title"))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)

                Text(String(localized: "onboarding.welcome.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 15)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: Location

    private var locationPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(.blue.opacity(animateContent ? 0.0 : 0.3), lineWidth: 1.5)
                        .frame(width: 160 + CGFloat(i) * 80, height: 160 + CGFloat(i) * 80)
                        .scaleEffect(animateContent ? 1.4 : 0.6)
                        .opacity(animateContent ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 2.5).repeatForever(autoreverses: false).delay(Double(i) * 0.6),
                            value: animateContent
                        )
                }

                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 200, height: 200)
                    .scaleEffect(animateContent ? 1.0 : 0.5)

                Circle()
                    .fill(.blue.opacity(0.04))
                    .frame(width: 260, height: 260)
                    .scaleEffect(animateContent ? 1.0 : 0.3)

                Image(systemName: "location.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.blue)
                    .scaleEffect(animateContent ? 1.0 : 0.3)
                    .opacity(animateContent ? 1 : 0)

                ForEach(0..<4, id: \.self) { i in
                    VStack(spacing: 2) {
                        Image(systemName: ["fork.knife", "cup.and.saucer.fill", "wineglass.fill", "takeoutbag.and.cup.and.straw.fill"][i])
                            .font(.system(size: [16, 14, 15, 13][i]))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.orange, in: Circle())
                            .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)

                        Triangle()
                            .fill(.orange)
                            .frame(width: 8, height: 5)
                    }
                    .offset(
                        x: [90, -80, 65, -95][i] * (animateContent ? 1 : 0.2),
                        y: [-50, -25, 55, 30][i] * (animateContent ? 1 : 0.2)
                    )
                    .opacity(animateContent ? 1 : 0)
                    .animation(
                        .spring(response: 0.7, dampingFraction: 0.6).delay(0.3 + Double(i) * 0.15),
                        value: animateContent
                    )
                }

                if locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                        .offset(x: 35, y: 35)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 300)

            VStack(spacing: 14) {
                Text(String(localized: "onboarding.location.title"))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)

                Text(String(localized: "onboarding.location.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 15)

                if locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(String(localized: "onboarding.location.granted"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            Spacer()
            Spacer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            locationStatus = locationManager.authorizationStatus
        }
        .onAppear {
            locationStatus = locationManager.authorizationStatus
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                let newStatus = locationManager.authorizationStatus
                if newStatus != locationStatus {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        locationStatus = newStatus
                    }
                }
                if currentPage != 1 && newStatus != .notDetermined {
                    timer.invalidate()
                }
            }
        }
    }

    // MARK: - Page 3: Scan

    private var scanPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.primary.opacity(0.2), lineWidth: 2)
                    .frame(width: 180, height: 280)
                    .scaleEffect(animateContent ? 1 : 0.7)
                    .opacity(animateContent ? 1 : 0)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<6, id: \.self) { i in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.primary.opacity(0.15))
                                .frame(width: CGFloat([90, 75, 100, 85, 70, 95][i]), height: 8)
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.primary.opacity(0.1))
                                .frame(width: 30, height: 8)
                        }
                        .frame(width: 140)
                        .opacity(animateContent ? 1 : 0)
                        .offset(x: animateContent ? 0 : -20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7).delay(0.3 + Double(i) * 0.08),
                            value: animateContent
                        )
                    }
                }

                RoundedRectangle(cornerRadius: 1)
                    .fill(.orange)
                    .frame(width: 150, height: 2)
                    .offset(y: animateContent ? 80 : -80)
                    .opacity(animateContent ? 0.6 : 0)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: animateContent
                    )

                VStack(spacing: 20) {
                    let checks = [
                        String(localized: "onboarding.scan.check1"),
                        String(localized: "onboarding.scan.check2"),
                        String(localized: "onboarding.scan.check3")
                    ]
                    ForEach(0..<3, id: \.self) { i in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 16))
                            Text(checks[i])
                                .font(.caption2.bold())
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                        .opacity(animateContent ? 1 : 0)
                        .offset(x: animateContent ? 0 : 30)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7).delay(0.8 + Double(i) * 0.25),
                            value: animateContent
                        )
                    }
                }
                .offset(x: 110, y: -20)
            }
            .frame(height: 300)

            VStack(spacing: 14) {
                Text(String(localized: "onboarding.scan.title"))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)

                Text(String(localized: "onboarding.scan.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 15)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 4: Results

    private var resultsPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                VStack(spacing: 10) {
                    resultCard(name: "Spare Ribs", score: 9, color: .green, delay: 0.2)
                    resultCard(name: "Caesar Bowl", score: 8, color: .green, delay: 0.4)
                    resultCard(name: "Quarkteigkrapfen", score: 9, color: .green, delay: 0.6)
                }

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                    Text("Top Picks")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.12), in: Capsule())
                .offset(x: 80, y: -95)
                .scaleEffect(animateContent ? 1 : 0.3)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.4), value: animateContent)

                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.yellow)
                    .offset(x: -110, y: -50)
                    .scaleEffect(animateContent ? 1 : 0)
                    .opacity(animateContent ? 0.8 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.7), value: animateContent)
            }
            .frame(height: 300)

            VStack(spacing: 14) {
                Text(String(localized: "onboarding.results.title"))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)

                Text(String(localized: "onboarding.results.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 15)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Result Card Helper

    private func resultCard(name: String, score: Int, color: Color, delay: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: animateContent ? CGFloat(score) / 10.0 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8).delay(delay + 0.3), value: animateContent)
                Text("\(score)")
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                    Text(String(localized: "onboarding.results.recommended"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .frame(width: 260)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay), value: animateContent)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? .orange : .primary.opacity(0.2))
                        .frame(width: i == currentPage ? 10 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }

            if currentPage == 3 {
                Button {
                    HapticsService.success()
                    withAnimation {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Text(String(localized: "onboarding.button.start"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 16))
                }
                .transition(.scale.combined(with: .opacity))
            } else if currentPage == 1 && locationStatus != .authorizedWhenInUse && locationStatus != .authorizedAlways {
                Button {
                    locationManager.requestWhenInUseAuthorization()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.subheadline)
                        Text(String(localized: "onboarding.location.button"))
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Button {
                    withAnimation {
                        currentPage += 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(String(localized: "onboarding.button.next"))
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
