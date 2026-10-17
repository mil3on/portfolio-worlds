extends RefCounted
## Portfolio content: the seven case-study locations on the planet.
##
## position     - where the location stands. Any vector; it is normalized into a
##                direction. The seven are spread evenly over the planet.
## caseUrl      - the page opened in a new browser tab when you interact with the
##                landmark. REPLACE THESE PLACEHOLDERS with your real portfolio URLs.
## accentColor  - the location's signature colour.
## description  - "Place name - short summary"; shown as the floating title above it.
## faceSea      - turn the location so its harbour side (+X) faces the sea.

## Centre of the planet's sea (the logistics port sits on its shore).
const SEA_DIR := Vector3(0.1205, -0.9903, 0.0696)

const LOCATIONS := [
	{
		"id": "origin",
		"title": "Origin",
		"description": "Лес целей - трекер жизни для целей и мотивации.",
		"interactionLabel": "E - Открыть кейс",
		"caseUrl": "https://mil3on.github.io/leondesign/origin-case/",
		"position": Vector3(0.0, 0.9135, -0.4067),
		"accentColor": Color(0.99, 0.81, 0.34),
		"builder": "origin",
	},
	{
		"id": "domtn",
		"title": "DOM TN",
		"description": "Квартал заявок - личный кабинет и дашборд обработки заявок клиентов.",
		"interactionLabel": "E - Открыть кейс",
		"caseUrl": "https://mil3on.github.io/leondesign/b2b-case/",
		"position": Vector3(0.8138, 0.342, -0.4698),
		"accentColor": Color(0.36, 0.66, 0.95),
		"builder": "domtn",
	},
	{
		"id": "smtu",
		"title": "SMTU",
		"description": "Корабельный университет - лендинг для приёмной кампании.",
		"interactionLabel": "E - Открыть кейс",
		"caseUrl": "https://www.behance.net/gallery/255621599/UNIVERSITY-LANDING-DESIGN-SMTU-EdTech-UXUI-",
		"position": Vector3(0.0, 0.342, 0.9397),
		"accentColor": Color(0.28, 0.52, 0.86),
		"builder": "smtu",
	},
	{
		"id": "itmo",
		"title": "ITMO NIOKTR",
		"description": "Сад науки - редизайн сайта научного конкурса.",
		"interactionLabel": "E - Открыть кейс",
		"caseUrl": "https://www.behance.net/gallery/221766175/UXUI-redizajn-sajta-nauchnogo-konkursa",
		"position": Vector3(-0.8138, 0.342, -0.4698),
		"accentColor": Color(0.25, 0.85, 0.88),
		"builder": "itmo",
	},
	{
		"id": "dragontrans",
		"title": "Dragontrans",
		"description": "Порт маршрутов - брендинг и сайт логистической компании.",
		"interactionLabel": "E - Открыть кейс",
		"caseUrl": "https://www.behance.net/gallery/247988945/DRAGONTRANS-Logistics-company-Website-design",
		"position": Vector3(0.6634, -0.6428, 0.383),
		"accentColor": Color(0.92, 0.28, 0.25),
		"builder": "dragontrans",
		"faceSea": true,
	},
	{
		"id": "book",
		"title": "Book At Home",
		"description": "Сад историй - сервис подписки для поиска и аренды книг.",
		"interactionLabel": "E - Открыть кейс",
		"caseUrl": "https://www.behance.net/gallery/218805071/servis-Book-at-home-UXUI-landing",
		"position": Vector3(0.0, -0.6428, -0.766),
		"accentColor": Color(0.95, 0.62, 0.25),
		"builder": "book",
	},
	{
		"id": "shots",
		"title": "Shots",
		"description": "Галерея интерфейсов - коллекция UI-концептов.",
		"interactionLabel": "E - Открыть кейс",
		"caseUrl": "SHOTS_CASE_URL",
		"position": Vector3(-0.6634, -0.6428, 0.383),
		"accentColor": Color(0.30, 0.55, 1.00),
		"builder": "shots",
	},
]
