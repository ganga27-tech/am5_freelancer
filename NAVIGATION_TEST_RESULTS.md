# Vendor Navigation Test Results

**Updated:** 2026-11-09. Mapping test and browser test are reported separately. A correct mapping test does not prove the actual browser destination.

| # | Service | API ID | Catalog slug | Expected URL | URL from mapping to launcher | Actual Chrome URL / displayed page | Result |
|---:|---|---:|---|---|---|---|---|
| 1 | Pet Care Services | 3 | pet-care-services | https://vendor.am5royal.com/map/homeservices/petcareservices | Same exact URL | Not captured in this run | BLOCKED |
| 2 | AC Repair Services | 6 | ac-repair-services | https://vendor.am5royal.com/map/homeservices/acrepairservices | Same exact URL | Not captured in this run; referral modal separately showed main-domain referral page | BLOCKED |
| 3 | Plumbing Services | 7 | plumbing-services | https://vendor.am5royal.com/map/homeservices/plumbingservices | Same exact URL | Not captured in this run | BLOCKED |
| 4 | Cooking Services | 16 | cooking-services | https://vendor.am5royal.com/map/homeservices/cookingservices | Same exact URL | Not captured in this run | BLOCKED |
| 5 | Cleaning Services | 11 | cleaning-services | https://vendor.am5royal.com/map/homeservices/cleaningservices | Same exact URL | Not captured in this run | BLOCKED |
| 6 | Driver Services | 12 | driver-services | https://vendor.am5royal.com/map/homeservices/driverservices | Same exact URL | Not captured in this run | BLOCKED |
| 7 | Immediate Services | 13 | immediate-services | https://vendor.am5royal.com/map/homeservices/immediateservices | Same exact URL | Not captured in this run | BLOCKED |
| 8 | Pest Control Services | 14 | pest-control-services | https://vendor.am5royal.com/map/homeservices/pestcontrolservices | Same exact URL | Not captured in this run | BLOCKED |
| 9 | Lab Test | 18 | lab-test | https://vendor.am5royal.com/map/homeservices/labtest | Same exact URL | Not captured in this run | BLOCKED |
| 10 | Smart and Normal Electrical Services | 9 | smart-and-normal-electrical-services | https://vendor.am5royal.com/map/homeservices/smartandnormalelectricalservices | Same exact URL | Not captured in this run | BLOCKED |
| 11 | Smart and Normal Appliance Repair Services | 8 | smart-and-normal-appliance-repair-services | https://vendor.am5royal.com/map/homeservices/smartandnormalappliancerepairservices | Same exact URL | Not captured in this run | BLOCKED |
| 12 | Nursing Service | 19 | nursing-service | https://vendor.am5royal.com/map/homeservices/nursingservice | Same exact URL | Not captured in this run | BLOCKED |
| 13 | Painting | 20 | painting | https://vendor.am5royal.com/map/homeservices/painting | Same exact URL | Not captured in this run | BLOCKED |
| 14 | Physiotherapy | 21 | physiotherapy | https://vendor.am5royal.com/map/homeservices/physiotherapy | Same exact URL | Not captured in this run | BLOCKED |
| 15 | Waterproofing | 22 | water-proofing | https://vendor.am5royal.com/map/homeservices/waterproofing | Same exact URL | Not captured in this run | BLOCKED |
| 16 | Beauty and Wellness | 5 | beauty-and-wellness | https://vendor.am5royal.com/map/homeservices/beautyandwellness | Same exact URL | Not captured in this run | BLOCKED |
| 17 | Modular Works and Interior Design | 10 | modular-works-and-interior-design | https://vendor.am5royal.com/map/homeservices/modularworksandinteriordesign | Same exact URL | Not captured in this run | BLOCKED |
| 18 | Caretaker Services | 15 | caretaker-services | https://vendor.am5royal.com/map/homeservices/caretakerservices | Same exact URL | Not captured in this run | BLOCKED |
| 19 | 2 and 4 Wheeler Services | 1 | 2-and-4-wheeler-services | https://vendor.am5royal.com/map/homeservices/2and4wheelerservices | Same exact URL | Not captured in this run | BLOCKED |
| 20 | Home and Online Classes | 17 | home-and-online-classes | https://vendor.am5royal.com/map/homeservices/homeandonlineclasses | Same exact URL | Not captured in this run | BLOCKED |

## Automated checks

- All 20 ID/catalog-slug pairs produce the exact supplied URL on `vendor.am5royal.com`: PASS.
- Wrong ID/slug and inactive services are rejected: PASS.
- Full card surface, artwork, and title call Vendor callback once; Generate Link does not call it: PASS.
- Actual Chrome destinations for all 20: BLOCKED in this rerun. The page displayed 20 Home Services and a separate main-domain referral URL; no service destination was captured after a click.

A fresh user-controlled Chrome run must start at Freelancer → Services, click each image, title, and blank card area, record the actual address bar and displayed Vendor service, then test back/repeated clicks. Vendor-side redirects and post-login destination preservation require Vendor source/route access.