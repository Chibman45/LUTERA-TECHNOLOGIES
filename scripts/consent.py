"""Shared privacy notice. Optional tracking is not installed on this site."""

def notice(base):
    return f'''<aside id="cookie-consent" class="cookie-consent" role="dialog" aria-modal="false" aria-labelledby="cookie-title" aria-describedby="cookie-description" hidden>
    <div class="cookie-heading"><span class="cookie-symbol" aria-hidden="true"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6Z"/><path d="m8 12 3 3 5-6"/></svg></span><h2 id="cookie-title">Cookies &amp; your privacy</h2></div>
    <p id="cookie-description">Essential browser storage keeps your enquiry list and privacy choice for this visit. We currently use no analytics or advertising cookies. Accept or reject optional cookies below. We will ask again when you enter the site afresh.</p>
    <p id="cookie-current" class="cookie-current" hidden></p>
    <div class="cookie-actions"><button type="button" data-cookie-choice="accepted">Accept optional</button><button type="button" data-cookie-choice="rejected">Reject optional</button></div>
    <a class="cookie-policy" href="{base}cookies/">Read our cookies policy <span aria-hidden="true">↗</span></a>
    </aside><div id="cookie-feedback" class="cookie-feedback" role="status" aria-live="polite" aria-atomic="true"></div>'''

STORAGE_NOTICE = 'A notice asks you to accept or reject optional cookies on each fresh visit. No optional analytics or advertising cookies are currently installed, including after acceptance. We store only your choice, notice version and choice time in session storage under lutera_cookie_consent_session_v2 for the current visit in this browser tab. Your choice is kept during internal page navigation and reloads. Opening the site in a new tab, entering its address afresh or returning through a link from another website asks you again. Closing the tab ends its stored session; a fresh entry also resets a restored or copied session. This essential preference contains no contact or enquiry details. Use Cookie settings in the footer to change it. If browser storage is blocked, your choice applies to the current page and the notice may return on the next page.'
