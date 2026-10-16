"""Owner-supplied company information shared by public pages."""
from html import escape
from urllib.parse import urlencode

STREET_ADDRESS = 'No. 7, Mahatma Gandhi Street, Area 11, Garki'
ADDRESS = STREET_ADDRESS + ', Abuja, FCT, Nigeria'
CITY = 'Abuja'
STATE = 'FCT'
LGA = 'AMAC (Abuja Municipal Area Council)'
HOUSE_NUMBER = 'No. 7'
NATURE_OF_BUSINESS = ('Information Technology and Artificial Intelligence (AI) Solutions; '
    'Technology Consultancy and IT Consulting Services; AI Agent Development and Business Process Automation; '
    'Software Design, Development and Implementation; Data Analytics; Systems Integration; Cloud-Based Solutions; '
    'Procurement, Importation, Exportation, Wholesale and Retail Supply of Computer Hardware, Accessories and Peripherals; '
    'Computer Installation, Maintenance and Technical Support; and Related Technology Services.')
MAP_URL = 'https://www.google.com/maps/search/?' + urlencode({'api': '1', 'query': ADDRESS})
DIGITAL_SERVICES = [
    ('ai', 'AI agents & automation', 'AI solutions, agent development and business process automation shaped around your workflows.'),
    ('software', 'Software development', 'Software design, development and implementation for the way your organization works.'),
    ('data', 'Data analytics', 'Turn business data into useful analysis to support planning and informed decisions.'),
    ('cloud', 'Cloud & systems integration', 'Connect your systems and explore cloud-based solutions around your business requirements.'),
]

def address_block():
    return '<address class="company-address">' + escape(ADDRESS) + '</address>'

def directions_link():
    return '<a class="text-link" href="' + escape(MAP_URL, quote=True) + '" target="_blank" rel="noopener noreferrer">View on Google Maps ↗</a>'

def company_details():
    return ('<section class="pale"><div class="wrap company-profile"><div><div class="eyebrow">COMPANY DETAILS</div>'
        '<h2>Based in Abuja.<br>Built around your business.</h2><dl class="company-facts">' +
        ''.join('<div><dt>' + label + '</dt><dd>' + escape(value) + '</dd></div>' for label, value in [
            ('Address', ADDRESS), ('City', CITY), ('State / FCT', STATE), ('LGA', LGA), ('House number', HOUSE_NUMBER)]) +
        '</dl>' + directions_link() + '</div><div class="company-scope"><h3>Nature of business</h3><p>' +
        escape(NATURE_OF_BUSINESS) + '</p></div></div></section>')

DIGITAL_SERVICE_IMAGES = {
    'ai': ('ai', 'Abstract AI lettering with connected digital paths'),
    'software': ('software', 'Software source code displayed on a development laptop'),
    'data': ('data', 'Analytics dashboard with charts and business metrics'),
    'cloud': ('servers', 'Connected server racks supporting cloud and integrated systems'),
}

def digital_services(base):
    return ('<section class="digital-services" id="digital-solutions"><div class="wrap"><div class="section-head"><div>'
        '<div class="eyebrow">AI, SOFTWARE & CONNECTED SYSTEMS</div><h2>Technology for the way<br>your business evolves.</h2></div>'
        '<p>Bring us the process you want to improve, the software you need to build or the systems you need to connect. We’ll discuss the requirements and agree the scope.</p></div>'
        '<div class="digital-grid">' + ''.join('<article class="card"><img src="' + base + 'assets/photos/' +
        DIGITAL_SERVICE_IMAGES[key][0] + '.jpg" width="960" height="640" loading="lazy" decoding="async" alt="' +
        escape(DIGITAL_SERVICE_IMAGES[key][1], quote=True) + '"><div class="digital-card-copy"><span class="mini-label">' + f'{i+1:02} / DIGITAL SOLUTIONS' +
        '</span><h3>' + escape(title) + '</h3><p>' + escape(description) + '</p><a class="text-link" href="' + base +
        'request-quote/?category=' + key + '">Discuss your project ↗</a></div></article>' for i,(key,title,description) in enumerate(DIGITAL_SERVICES)) +
        '</div></div></section>')
