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

    -- storefront
    prompt_browse           = 'Browse',
    prompt_manage           = 'Manage Store',
    err_char_not_ready      = 'Your character isn\'t ready yet — give it a moment and try again.',
    wage_paid               = 'Wages paid: $%.2f',
    clocked_out_wandered    = 'You wandered from the store — the clock punched you out.',
    presence_warning        = 'The clock notices you\'re away from the counter…',
    bought_total            = 'Purchase complete — $%.2f.',
    sold_total              = 'Sold — $%.2f received.',
    store_err_unknown_store = 'That store isn\'t trading right now.',
    store_err_too_far       = 'Step up to the counter first.',
    store_err_job_locked    = 'This store doesn\'t serve your line of work.',
    store_err_unknown       = 'The clerk seems distracted — try again.',
    store_err_no_response   = 'The clerk seems distracted — try again.',
    store_err_closed        = 'That store is closed right now.',
    err_not_staff           = 'You don\'t work at any store in the county.',
}

-- ── Phase 4: taxes, letters, webhooks, buy orders ───────────────────
Locales['en'].letter_sender = 'Sovereign County Commerce Bureau'

Locales['en'].letter_tax_receipt_subject = 'Receipt of Property Tax'
Locales['en'].letter_tax_receipt_body =
    'The Bureau acknowledges receipt of property tax for %s in the amount of $%.2f.\n\n' ..
    'Your account stands current. The next assessment falls due %s.\n\n' ..
    'Keep this notice with your papers.'

Locales['en'].letter_delinquent_subject = 'NOTICE OF DELINQUENT TAX'
Locales['en'].letter_delinquent_body =
    'The property tax assessed against %s, in the amount of $%.2f, could not be collected.\n\n' ..
    'Neither the tax reserve nor the operating ledger held sufficient funds.\n\n' ..
    'You have %d hours to deposit the amount owed into the store\'s tax reserve. ' ..
    'The Bureau will attempt collection once more when that time expires.\n\n' ..
    'Should it fail again, the property will be repossessed by the county, its ledgers ' ..
    'swept to the treasury, and its roster dissolved.'

Locales['en'].letter_seized_subject = 'ORDER OF REPOSSESSION'
Locales['en'].letter_seized_body =
    'For failure to satisfy property tax of $%.2f, the county has this day repossessed %s.\n\n' ..
    'Ledgers have been swept to the treasury and the roster dissolved. ' ..
    'You may petition the Bureau should you wish to be heard.'

Locales['en'].letter_inactive_warn_subject = 'Notice of Absence'
Locales['en'].letter_inactive_warn_body =
    'The doors of %s have stood shut for %d days.\n\n' ..
    'The county charters storefronts to those who will trade from them. Should the ' ..
    'absence continue another %d days, the charter will be revoked and the property ' ..
    'returned to the county for re-charter.\n\n' ..
    'Return and open your doors, or petition the Bureau for an approved absence.'

Locales['en'].letter_inactive_seized_subject = 'CHARTER REVOKED — ABSENCE'
Locales['en'].letter_inactive_seized_body =
    'The charter for %s is revoked this day, the property having stood idle %d days.\n\n' ..
    'The premises return to the county for re-charter.'

-- webhook embeds
Locales['en'].wh_username        = 'Sovereign County Commerce Bureau'
Locales['en'].wh_footer          = 'Sovereign County RP · sovereign_stores'
Locales['en'].wh_store           = 'Store'
Locales['en'].wh_amount          = 'Amount'
Locales['en'].wh_item            = 'Goods'
Locales['en'].wh_reason          = 'Reason'
Locales['en'].wh_deadline        = 'Deadline'
Locales['en'].wh_swept           = 'Swept to treasury'
Locales['en'].wh_tax_paid        = 'Property tax collected'
Locales['en'].wh_tax_delinquent  = 'TAX DELINQUENT'
Locales['en'].wh_repossessed     = 'STORE REPOSSESSED'
Locales['en'].wh_reason_tax      = 'Unpaid property tax'
Locales['en'].wh_reason_inactive = 'Owner absent %d days'
Locales['en'].wh_buy_order_filled = 'Buy order filled'

-- buy orders / storefront
Locales['en'].sold_to_store      = 'Sold to the store — $%.2f'
Locales['en'].wh_sale            = 'Sale'
Locales['en'].wh_opened          = 'Store opened'
Locales['en'].wh_closed          = 'Store closed'
Locales['en'].wh_staff           = 'Roster change'

-- realty integration (I3)
Locales['en'].store_released_paid = 'The business accounts are settled — $%.2f paid out to you.'
