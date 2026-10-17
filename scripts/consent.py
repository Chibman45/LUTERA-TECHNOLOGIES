"""Shared privacy notice. Optional tracking is not installed on this site."""

def notice(base):
    return f'''<aside id="cookie-consent" class="cookie-consent" role="dialog" aria-modal="false" aria-labelledby="cookie-title" aria-describedby="cookie-description" hidden>
    <div class="cookie-heading"><span class="cookie-symbol" aria-hidden="true"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6Z"/><path d="m8 12 3 3 5-6"/></svg></span><h2 id="cookie-title">Cookies &amp; your privacy</h2></div>
    <p id="cookie-description">Essential browser storage keeps your enquiry list and remembers your privacy choice. We currently use no analytics or advertising cookies. You can accept or reject optional cookies; either choice keeps the site working.</p>
    <p id="cookie-current" class="cookie-current" hidden></p>
    <div class="cookie-actions"><button type="button" data-cookie-choice="accepted">Accept optional</button><button type="button" data-cookie-choice="rejected">Reject optional</button></div>
    <a class="cookie-policy" href="{base}cookies/">Read our cookies policy <span aria-hidden="true">↗</span></a>
    </aside><div id="cookie-feedback" class="cookie-feedback" role="status" aria-live="polite" aria-atomic="true"></div>'''

STORAGE_NOTICE = 'A first-visit notice lets you accept or reject optional cookies. No optional analytics or advertising cookies are currently installed, including after acceptance. We store only your choice, notice version and choice/expiry times in local storage under lutera_cookie_consent_v1 for 180 days. This essential preference contains no contact or enquiry details. Use Cookie settings in the footer to change it. Clearing site storage, using another browser or the preference expiring will show the notice again. If browser storage is blocked, your choice applies to the current page and the notice may return on your next visit.'
