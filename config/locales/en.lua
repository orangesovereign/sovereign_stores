Locales = Locales or {}

Locales['en'] = {
    -- boot / diag
    boot_ok          = 'sovereign_stores booted clean (v%s)',
    boot_problems    = 'sovereign_stores booted WITH PROBLEMS — run /stores_diag',
    diag_header      = 'Sovereign Stores — diagnostic report',
    diag_deps        = 'Dependencies',
    diag_schema      = 'Database schema',
    diag_config      = 'Config validation',
    diag_ok          = 'OK',
    diag_missing     = 'MISSING',
    diag_notify_ok   = 'Diagnostics green — details in server console.',
    diag_notify_bad  = 'Diagnostics found problems — see server console.',

    -- generic
    err_no_permission = 'You don\'t have permission to do that.',
    err_not_ready     = 'The store system isn\'t ready yet — try again shortly.',
}
