@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Die Skripte sind interaktive Trainerwerkzeuge; farbige Konsolenausgabe ist gewollt.
        'PSAvoidUsingWriteHost',
        # Interne Hilfsfunktionen; ShouldProcess sitzt an den Skript-Einstiegen (Remove-Workshop).
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        # Pester-Mocks laufen im Modulscope und brauchen einen gemeinsamen Zustand.
        'PSAvoidGlobalVars',
        # Initialize-Workshop erzeugt Passwoerter auf dem DC und uebergibt sie nur im Arbeitsspeicher an New-ADUser.
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingPlainTextForPassword'
    )
}
