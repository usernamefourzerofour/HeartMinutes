"""Promotional text for version 1.0.1: workouts count, and background activity is logged automatically.

Run once to write the texts into app-store.json: python3 Localization/promo_101.py
"""
import json
import pathlib

PROMO = {
    "en": "Workouts count – and so does everything in between: Apple Watch measures your heart rate in the background, so brisk walks and bike rides are logged automatically.",
    "ar": "التمارين تُحتسب – وكذلك كل ما بينها: تقيس Apple Watch نبضك في الخلفية، فتُسجَّل المشي السريع وركوب الدراجة تلقائيًا.",
    "bg": "Тренировките се броят – и всичко между тях: Apple Watch мери пулса ви във фонов режим, така че бързото ходене и колоезденето се записват автоматично.",
    "ca": "Els entrenaments compten, i tot el que hi ha entremig també: l'Apple Watch mesura el pols en segon pla i les caminades ràpides i la bici es registren soles.",
    "cs": "Tréninky se počítají – a vše mezi nimi taky: Apple Watch měří tep na pozadí, takže svižná chůze a jízda na kole se zaznamenají automaticky.",
    "da": "Træning tæller – og det gør alt det ind imellem også: Apple Watch måler pulsen i baggrunden, så rask gang og cykelture logges automatisk.",
    "de": "Workouts zählen – und alles dazwischen auch: Die Apple Watch misst deinen Puls im Hintergrund, so werden zügiges Gehen und Radfahren automatisch erfasst.",
    "el": "Οι προπονήσεις μετράνε – και ό,τι γίνεται ενδιάμεσα: το Apple Watch μετρά τον παλμό στο παρασκήνιο και το γρήγορο περπάτημα καταγράφεται αυτόματα.",
    "es": "Los entrenamientos cuentan, y todo lo de en medio también: el Apple Watch mide tu pulso en segundo plano y los paseos rápidos y la bici se registran solos.",
    "es-419": "Los entrenamientos cuentan, y todo lo de en medio también: el Apple Watch mide tu pulso en segundo plano y las caminatas rápidas y la bici se registran solas.",
    "fi": "Treenit lasketaan – ja kaikki niiden välissä myös: Apple Watch mittaa sykettä taustalla, joten reipas kävely ja pyöräily kirjautuvat automaattisesti.",
    "fr": "Les séances comptent, et tout le reste aussi : l'Apple Watch mesure votre pouls en arrière-plan, la marche rapide et le vélo sont enregistrés automatiquement.",
    "he": "אימונים נספרים – וגם כל מה שביניהם: Apple Watch מודד את הדופק ברקע, כך שהליכה מהירה ורכיבה על אופניים נרשמות אוטומטית.",
    "hi": "वर्कआउट गिने जाते हैं – और बीच की हर गतिविधि भी: Apple Watch बैकग्राउंड में धड़कन मापती है, तेज़ चलना और साइकिल चलाना अपने-आप दर्ज होता है।",
    "hr": "Treninzi se broje – i sve između njih: Apple Watch mjeri puls u pozadini, pa se brzo hodanje i vožnja biciklom bilježe automatski.",
    "hu": "Az edzések számítanak – és minden, ami köztük van: az Apple Watch a háttérben méri a pulzust, így a tempós séta és a biciklizés automatikusan rögzül.",
    "id": "Latihan dihitung – begitu juga semua di antaranya: Apple Watch mengukur detak jantung di latar belakang, jadi jalan cepat dan bersepeda tercatat otomatis.",
    "it": "Gli allenamenti contano, e anche tutto il resto: Apple Watch misura il battito in background, così camminate veloci e giri in bici vengono registrati da soli.",
    "ja": "ワークアウトはもちろん、その合間の活動もカウント。Apple Watchがバックグラウンドで心拍数を測るので、早歩きや自転車も自動で記録されます。",
    "ko": "운동은 물론 그 사이의 활동도 계산됩니다. Apple Watch가 백그라운드에서 심박수를 측정해 빠르게 걷기와 자전거 타기가 자동으로 기록됩니다.",
    "lt": "Treniruotės skaičiuojamos – ir viskas tarp jų: Apple Watch matuoja pulsą fone, todėl greitas ėjimas ir važiavimas dviračiu užregistruojami automatiškai.",
    "ms": "Senaman dikira – begitu juga semua di antaranya: Apple Watch mengukur nadi di latar belakang, jadi jalan pantas dan berbasikal direkod secara automatik.",
    "nb": "Trening teller – og det gjør alt imellom også: Apple Watch måler pulsen i bakgrunnen, så rask gange og sykkelturer logges automatisk.",
    "nl": "Workouts tellen – en alles daartussen ook: Apple Watch meet je hartslag op de achtergrond, dus stevig wandelen en fietsen worden automatisch vastgelegd.",
    "pl": "Treningi się liczą – i wszystko pomiędzy: Apple Watch mierzy tętno w tle, więc szybki marsz i jazda na rowerze zapisują się automatycznie.",
    "pt-BR": "Os treinos contam, e tudo entre eles também: o Apple Watch mede seus batimentos em segundo plano, e caminhadas rápidas e pedaladas são registradas sozinhas.",
    "pt-PT": "Os treinos contam, e tudo o que fica pelo meio também: o Apple Watch mede o pulso em segundo plano, e caminhadas rápidas e voltas de bicicleta ficam registadas.",
    "ro": "Antrenamentele contează – și tot ce e între ele: Apple Watch măsoară pulsul în fundal, așa că mersul alert și mersul pe bicicletă se înregistrează automat.",
    "ru": "Тренировки учитываются – и всё, что между ними: Apple Watch измеряет пульс в фоне, поэтому быстрая ходьба и велопрогулки записываются автоматически.",
    "sk": "Tréningy sa počítajú – a všetko medzi nimi tiež: Apple Watch meria tep na pozadí, takže svižná chôdza a bicyklovanie sa zaznamenajú automaticky.",
    "sl": "Vadbe štejejo – in vse vmes tudi: Apple Watch meri utrip v ozadju, zato se hitra hoja in kolesarjenje zabeležita samodejno.",
    "sv": "Träningspass räknas – och allt däremellan också: Apple Watch mäter pulsen i bakgrunden, så rask promenad och cykling loggas automatiskt.",
    "th": "การออกกำลังกายนับรวม และกิจกรรมระหว่างวันก็นับด้วย: Apple Watch วัดชีพจรเบื้องหลัง การเดินเร็วและปั่นจักรยานจึงถูกบันทึกอัตโนมัติ",
    "tr": "Antrenmanlar sayılır – aradaki her şey de: Apple Watch nabzınızı arka planda ölçer, böylece tempolu yürüyüş ve bisiklet otomatik olarak kaydedilir.",
    "uk": "Тренування враховуються – і все між ними: Apple Watch вимірює пульс у фоні, тож швидка ходьба та їзда на велосипеді записуються автоматично.",
    "vi": "Buổi tập được tính – và mọi hoạt động ở giữa cũng vậy: Apple Watch đo nhịp tim ở chế độ nền, nên đi bộ nhanh và đạp xe được ghi lại tự động.",
    "zh-Hans": "锻炼会计入，锻炼之外的活动也一样：Apple Watch 在后台测量心率，快走和骑车都会自动记录。",
    "zh-Hant": "體能訓練會計入，訓練之外的活動也一樣：Apple Watch 在背景測量心率，快走和騎單車都會自動記錄。",
}

if __name__ == "__main__":
    path = pathlib.Path(__file__).with_name("app-store.json")
    data = json.loads(path.read_text())
    assert set(PROMO) == set(data), set(data) ^ set(PROMO)
    for lang, text in PROMO.items():
        assert len(text) <= 170, (lang, len(text))
        data[lang]["promotional_text"] = text
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("updated", len(PROMO), "languages; longest", max(len(t) for t in PROMO.values()))
