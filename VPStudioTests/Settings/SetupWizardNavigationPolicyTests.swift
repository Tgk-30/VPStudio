import Testing
@testable import VPStudio

@Suite("SetupWizardNavigationPolicy")
struct SetupWizardNavigationPolicyTests {
    @Test
    func clampedStepBoundsRequestedStepToWizardRange() {
        #expect(SetupWizardNavigationPolicy.clampedStep(-4, totalSteps: 5) == 0)
        #expect(SetupWizardNavigationPolicy.clampedStep(0, totalSteps: 5) == 0)
        #expect(SetupWizardNavigationPolicy.clampedStep(3, totalSteps: 5) == 3)
        #expect(SetupWizardNavigationPolicy.clampedStep(9, totalSteps: 5) == 4)
        #expect(SetupWizardNavigationPolicy.clampedStep(2, totalSteps: 0) == 0)
    }

    @Test
    func navigationButtonsReflectIntermediateAndCompleteSteps() {
        #expect(SetupWizardNavigationPolicy.showsBackButton(currentStep: 0, totalSteps: 5) == false)
        #expect(SetupWizardNavigationPolicy.showsContinueButton(currentStep: 0, totalSteps: 5) == false)

        #expect(SetupWizardNavigationPolicy.showsBackButton(currentStep: 1, totalSteps: 5))
        #expect(SetupWizardNavigationPolicy.showsContinueButton(currentStep: 1, totalSteps: 5))
        #expect(SetupWizardNavigationPolicy.showsStartExploringButton(currentStep: 1, totalSteps: 5) == false)

        #expect(SetupWizardNavigationPolicy.showsBackButton(currentStep: 4, totalSteps: 5) == false)
        #expect(SetupWizardNavigationPolicy.showsContinueButton(currentStep: 4, totalSteps: 5) == false)
        #expect(SetupWizardNavigationPolicy.showsStartExploringButton(currentStep: 4, totalSteps: 5))
    }

    @Test
    func stepIndicatorAccessibilityValueUsesOneBasedClampedStepCount() {
        #expect(
            SetupWizardNavigationPolicy.stepIndicatorAccessibilityValue(currentStep: 0, totalSteps: 5)
                == "Step 1 of 5"
        )
        #expect(
            SetupWizardNavigationPolicy.stepIndicatorAccessibilityValue(currentStep: 3, totalSteps: 5)
                == "Step 4 of 5"
        )
        #expect(
            SetupWizardNavigationPolicy.stepIndicatorAccessibilityValue(currentStep: 8, totalSteps: 5)
                == "Step 5 of 5"
        )
        #expect(
            SetupWizardNavigationPolicy.stepIndicatorAccessibilityValue(currentStep: -1, totalSteps: 0)
                == "Step 1 of 1"
        )
    }
}

@Suite("SetupWizardTransitionPolicy")
struct SetupWizardTransitionPolicyTests {
    @Test
    func transitionClampsRequestedStepAndAnimatesWhenMotionIsAllowed() {
        let forward = SetupWizardTransitionPolicy.transition(
            currentStep: 1,
            requestedStep: 2,
            totalSteps: 5,
            reduceMotion: false
        )
        #expect(forward == SetupWizardTransitionPolicy.StepTransition(
            targetStep: 2,
            shouldUpdate: true,
            shouldAnimate: true
        ))

        let clampedOverflow = SetupWizardTransitionPolicy.transition(
            currentStep: 3,
            requestedStep: 99,
            totalSteps: 5,
            reduceMotion: false
        )
        #expect(clampedOverflow.targetStep == 4)
        #expect(clampedOverflow.shouldUpdate)
        #expect(clampedOverflow.shouldAnimate)
    }

    @Test
    func transitionNoopsWhenRequestedStepClampsToCurrentStep() {
        let sameStep = SetupWizardTransitionPolicy.transition(
            currentStep: 0,
            requestedStep: -4,
            totalSteps: 5,
            reduceMotion: false
        )

        #expect(sameStep.targetStep == 0)
        #expect(sameStep.shouldUpdate == false)
        #expect(sameStep.shouldAnimate == false)
    }

    @Test
    func transitionUpdatesWithoutAnimationWhenReduceMotionIsEnabled() {
        let reducedMotion = SetupWizardTransitionPolicy.transition(
            currentStep: 1,
            requestedStep: 2,
            totalSteps: 5,
            reduceMotion: true
        )

        #expect(reducedMotion.targetStep == 2)
        #expect(reducedMotion.shouldUpdate)
        #expect(reducedMotion.shouldAnimate == false)
    }

    @Test
    func advancedTransitionRequestsTheNextStepAndClampsAtTheEnd() {
        let next = SetupWizardTransitionPolicy.advancedTransition(
            currentStep: 2,
            totalSteps: 5,
            reduceMotion: false
        )
        #expect(next.targetStep == 3)
        #expect(next.shouldUpdate)
        #expect(next.shouldAnimate)

        let complete = SetupWizardTransitionPolicy.advancedTransition(
            currentStep: 4,
            totalSteps: 5,
            reduceMotion: false
        )
        #expect(complete.targetStep == 4)
        #expect(complete.shouldUpdate == false)
        #expect(complete.shouldAnimate == false)
    }
}

@Suite("SetupWizardQAAutoAdvancePolicy")
struct SetupWizardQAAutoAdvancePolicyTests {
    @Test
    func shouldStartAutoAdvanceRequiresEnabledAndNotAlreadyRun() {
        #expect(SetupWizardQAAutoAdvancePolicy.shouldStartAutoAdvance(isEnabled: true, didRun: false))
        #expect(SetupWizardQAAutoAdvancePolicy.shouldStartAutoAdvance(isEnabled: false, didRun: false) == false)
        #expect(SetupWizardQAAutoAdvancePolicy.shouldStartAutoAdvance(isEnabled: true, didRun: true) == false)
    }

    @Test
    func autoAdvanceContinuesOnlyThroughIntermediateSteps() {
        #expect(SetupWizardQAAutoAdvancePolicy.shouldContinueAutoAdvance(currentStep: 0, totalSteps: 5) == false)
        #expect(SetupWizardQAAutoAdvancePolicy.shouldContinueAutoAdvance(currentStep: 1, totalSteps: 5))
        #expect(SetupWizardQAAutoAdvancePolicy.shouldContinueAutoAdvance(currentStep: 3, totalSteps: 5))
        #expect(SetupWizardQAAutoAdvancePolicy.shouldContinueAutoAdvance(currentStep: 4, totalSteps: 5) == false)
    }

    @Test
    func shouldDismissAfterAutoAdvanceOnlyOnCompleteStep() {
        #expect(SetupWizardQAAutoAdvancePolicy.shouldDismissAfterAutoAdvance(currentStep: 3, totalSteps: 5) == false)
        #expect(SetupWizardQAAutoAdvancePolicy.shouldDismissAfterAutoAdvance(currentStep: 4, totalSteps: 5))
        #expect(SetupWizardQAAutoAdvancePolicy.shouldDismissAfterAutoAdvance(currentStep: 0, totalSteps: 0) == false)
    }

    @Test
    func appliedDefaultsUsesOnlyProvidedQAOverrides() {
        let defaults = SetupWizardQAAutoAdvancePolicy.appliedDefaults(
            tmdbApiKey: "existing-tmdb",
            selectedQuality: .hd1080p,
            selectedSubtitleLanguage: .none,
            overrideTMDBApiKey: "qa-tmdb",
            overridePreferredQuality: nil,
            overrideSubtitleLanguage: .english
        )

        #expect(defaults.tmdbApiKey == "qa-tmdb")
        #expect(defaults.selectedQuality == .hd1080p)
        #expect(defaults.selectedSubtitleLanguage == .english)
    }
}
