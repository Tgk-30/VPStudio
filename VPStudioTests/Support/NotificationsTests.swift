import Foundation
import Testing
@testable import VPStudio

@Suite("Notifications")
struct NotificationsTests {
    @Test func libraryDidChangeHasCorrectName() {
        #expect(Notification.Name.libraryDidChange.rawValue == "VPStudio.LibraryDidChange")
    }

    @Test func tasteProfileDidChangeHasCorrectName() {
        #expect(Notification.Name.tasteProfileDidChange.rawValue == "VPStudio.TasteProfileDidChange")
    }

    @Test func settingsDidChangeHasCorrectName() {
        #expect(Notification.Name.settingsDidChange.rawValue == "VPStudio.SettingsDidChange")
    }

    @Test func discoverAISettingsDidChangeHasCorrectName() {
        #expect(Notification.Name.discoverAISettingsDidChange.rawValue == "VPStudio.DiscoverAISettingsDidChange")
    }

    @Test func downloadsDidChangeHasCorrectName() {
        #expect(Notification.Name.downloadsDidChange.rawValue == "VPStudio.DownloadsDidChange")
    }

    @Test func watchHistoryDidChangeHasCorrectName() {
        #expect(Notification.Name.watchHistoryDidChange.rawValue == "VPStudio.WatchHistoryDidChange")
    }

    @Test func openSubtitlesDidChangeHasCorrectName() {
        #expect(Notification.Name.openSubtitlesDidChange.rawValue == "VPStudio.OpenSubtitlesDidChange")
    }

    @Test func environmentsDidChangeHasCorrectName() {
        #expect(Notification.Name.environmentsDidChange.rawValue == "VPStudio.EnvironmentsDidChange")
    }

    @Test func indexersDidChangeHasCorrectName() {
        #expect(Notification.Name.indexersDidChange.rawValue == "VPStudio.IndexersDidChange")
    }

    @Test func tmdbApiKeyDidChangeHasCorrectName() {
        #expect(Notification.Name.tmdbApiKeyDidChange.rawValue == "VPStudio.TMDBApiKeyDidChange")
    }

    @Test func appDidResetAllDataHasCorrectName() {
        #expect(Notification.Name.appDidResetAllData.rawValue == "VPStudio.AppDidResetAllData")
    }

    @Test func localModelsDidChangeHasCorrectName() {
        #expect(Notification.Name.localModelsDidChange.rawValue == "VPStudio.LocalModelsDidChange")
    }

    @Test func immersiveTapCatcherDidFireHasCorrectName() {
        #expect(Notification.Name.immersiveTapCatcherDidFire.rawValue == "VPStudio.ImmersiveTapCatcherDidFire")
    }

    @Test func immersiveControlTogglePlayPauseHasCorrectName() {
        #expect(Notification.Name.immersiveControlTogglePlayPause.rawValue == "VPStudio.ImmersiveControl.TogglePlayPause")
    }

    @Test func immersiveControlSeekBackHasCorrectName() {
        #expect(Notification.Name.immersiveControlSeekBack.rawValue == "VPStudio.ImmersiveControl.SeekBack")
    }

    @Test func immersiveControlSeekForwardHasCorrectName() {
        #expect(Notification.Name.immersiveControlSeekForward.rawValue == "VPStudio.ImmersiveControl.SeekForward")
    }

    @Test func immersiveControlSeekToPercentHasCorrectName() {
        #expect(Notification.Name.immersiveControlSeekToPercent.rawValue == "VPStudio.ImmersiveControl.SeekToPercent")
    }

    @Test func immersiveControlPreviousChapterHasCorrectName() {
        #expect(Notification.Name.immersiveControlPreviousChapter.rawValue == "VPStudio.ImmersiveControl.PreviousChapter")
    }

    @Test func immersiveControlNextChapterHasCorrectName() {
        #expect(Notification.Name.immersiveControlNextChapter.rawValue == "VPStudio.ImmersiveControl.NextChapter")
    }

    @Test func immersiveControlCycleRateHasCorrectName() {
        #expect(Notification.Name.immersiveControlCycleRate.rawValue == "VPStudio.ImmersiveControl.CycleRate")
    }

    @Test func immersiveControlToggleSubtitlesHasCorrectName() {
        #expect(Notification.Name.immersiveControlToggleSubtitles.rawValue == "VPStudio.ImmersiveControl.ToggleSubtitles")
    }

    @Test func immersiveControlToggleAudioHasCorrectName() {
        #expect(Notification.Name.immersiveControlToggleAudio.rawValue == "VPStudio.ImmersiveControl.ToggleAudio")
    }

    @Test func immersiveControlRequestEnvironmentSwitchHasCorrectName() {
        #expect(Notification.Name.immersiveControlRequestEnvironmentSwitch.rawValue == "VPStudio.ImmersiveControl.RequestEnvironmentSwitch")
    }

    @Test func immersiveControlDismissHasCorrectName() {
        #expect(Notification.Name.immersiveControlDismiss.rawValue == "VPStudio.ImmersiveControl.Dismiss")
    }

    @Test func immersiveControlCycleScreenSizeHasCorrectName() {
        #expect(Notification.Name.immersiveControlCycleScreenSize.rawValue == "VPStudio.ImmersiveControl.CycleScreenSize")
    }

    @Test func playerAutoplayControlNamesAreStable() {
        #expect(Notification.Name.playerAutoplayControlPlayNow.rawValue == "VPStudio.PlayerAutoplayControl.PlayNow")
        #expect(Notification.Name.playerAutoplayControlCancel.rawValue == "VPStudio.PlayerAutoplayControl.Cancel")
        #expect(Notification.Name.playerAutoplayControlProgress.rawValue == "VPStudio.PlayerAutoplayControl.Progress")
    }

    @Test func playerSubtitleControlNamesAreStable() {
        #expect(Notification.Name.playerSubtitleControlRefreshCatalog.rawValue == "VPStudio.PlayerSubtitleControl.RefreshCatalog")
        #expect(Notification.Name.playerSubtitleControlDownload.rawValue == "VPStudio.PlayerSubtitleControl.Download")
    }

    @Test func libraryCSVImportControlNamesAreStable() {
        #expect(Notification.Name.libraryCSVImportControlImportFiles.rawValue == "VPStudio.LibraryCSVImportControl.ImportFiles")
        #expect(Notification.Name.libraryCSVImportControlImportFolder.rawValue == "VPStudio.LibraryCSVImportControl.ImportFolder")
    }

    @Test func aiSettingsControlNamesAreStable() {
        #expect(Notification.Name.aiSettingsControlPersistCloudCredential.rawValue == "VPStudio.AISettingsControl.PersistCloudCredential")
        #expect(Notification.Name.aiSettingsControlDeleteCloudCredential.rawValue == "VPStudio.AISettingsControl.DeleteCloudCredential")
        #expect(Notification.Name.aiSettingsControlPersistOllamaEndpoint.rawValue == "VPStudio.AISettingsControl.PersistOllamaEndpoint")
        #expect(Notification.Name.aiSettingsControlPersistStringSetting.rawValue == "VPStudio.AISettingsControl.PersistStringSetting")
        #expect(Notification.Name.aiSettingsControlPersistBoolSetting.rawValue == "VPStudio.AISettingsControl.PersistBoolSetting")
        #expect(Notification.Name.aiSettingsControlScheduleModelPresetSave.rawValue == "VPStudio.AISettingsControl.ScheduleModelPresetSave")
        #expect(Notification.Name.aiSettingsControlResetUsageStats.rawValue == "VPStudio.AISettingsControl.ResetUsageStats")
    }
}
