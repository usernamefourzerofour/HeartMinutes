"""Version 1.0.1: replaces the description's second section with "Workouts + everyday activity".

Workouts count, and on top of that the watch's background heart rate is logged automatically – without starting a
workout. Run once: python3 Localization/description_101.py
(Applied together with moving the "On your wrist and Home Screen" section up to the third place – widgets and
complications are the app's main interface.)
"""
import json
import pathlib

SECTION = {
    "en": "WORKOUTS + EVERYDAY ACTIVITY\n"
          "• Workouts: every workout counts, with its heart rate and zones in detail.\n"
          "• Everyday activity: your Apple Watch measures your heart rate in the background all day, and Heart Minutes "
          "logs it automatically. A brisk walk, cycling to work or taking the stairs counts – without starting a workout.",
    "ar": "التمارين + النشاط اليومي\n"
          "• التمارين: كل تمرين يُحتسب، مع تفاصيل النبض والمناطق.\n"
          "• النشاط اليومي: تقيس Apple Watch نبضك في الخلفية طوال اليوم، ويسجّله Heart Minutes تلقائيًا. "
          "المشي السريع أو ركوب الدراجة إلى العمل أو صعود الدرج يُحتسب – دون بدء تمرين.",
    "bg": "ТРЕНИРОВКИ + ЕЖЕДНЕВНА АКТИВНОСТ\n"
          "• Тренировки: всяка тренировка се брои, с подробен пулс и зони.\n"
          "• Ежедневна активност: Apple Watch мери пулса ви във фонов режим през целия ден, а Heart Minutes го записва "
          "автоматично. Бързо ходене, колоездене до работа или изкачване на стълби се броят – без да стартирате тренировка.",
    "ca": "ENTRENAMENTS + ACTIVITAT DIÀRIA\n"
          "• Entrenaments: cada entrenament compta, amb el pols i les zones en detall.\n"
          "• Activitat diària: l'Apple Watch mesura el pols en segon pla tot el dia i Heart Minutes ho registra "
          "automàticament. Una caminada ràpida, anar a la feina en bici o pujar escales compta, sense iniciar cap entrenament.",
    "cs": "TRÉNINKY + BĚŽNÁ AKTIVITA\n"
          "• Tréninky: každý trénink se počítá, s podrobným tepem a zónami.\n"
          "• Běžná aktivita: Apple Watch měří tep na pozadí po celý den a Heart Minutes ho automaticky zaznamenává. "
          "Svižná chůze, cesta do práce na kole nebo schody se počítají – bez spouštění tréninku.",
    "da": "TRÆNING + HVERDAGSAKTIVITET\n"
          "• Træning: hver træning tæller, med puls og zoner i detaljer.\n"
          "• Hverdagsaktivitet: dit Apple Watch måler pulsen i baggrunden hele dagen, og Heart Minutes logger den "
          "automatisk. Rask gang, cykelturen til arbejde eller trapperne tæller – uden at du starter en træning.",
    "de": "WORKOUTS + ALLTAGSAKTIVITÄT\n"
          "• Workouts: Jedes Training zählt, mit Puls und Zonen im Detail.\n"
          "• Alltagsaktivität: Deine Apple Watch misst den Puls den ganzen Tag im Hintergrund, und Heart Minutes erfasst "
          "ihn automatisch. Zügiges Gehen, mit dem Rad zur Arbeit oder Treppensteigen zählt – ohne ein Training zu starten.",
    "el": "ΠΡΟΠΟΝΗΣΕΙΣ + ΚΑΘΗΜΕΡΙΝΗ ΔΡΑΣΤΗΡΙΟΤΗΤΑ\n"
          "• Προπονήσεις: κάθε προπόνηση μετράει, με αναλυτικό παλμό και ζώνες.\n"
          "• Καθημερινή δραστηριότητα: το Apple Watch μετρά τον παλμό σας στο παρασκήνιο όλη μέρα και το Heart Minutes "
          "τον καταγράφει αυτόματα. Γρήγορο περπάτημα, ποδήλατο για τη δουλειά ή σκάλες μετράνε – χωρίς να ξεκινήσετε προπόνηση.",
    "es": "ENTRENAMIENTOS + ACTIVIDAD DIARIA\n"
          "• Entrenamientos: cada entrenamiento cuenta, con el pulso y las zonas en detalle.\n"
          "• Actividad diaria: tu Apple Watch mide el pulso en segundo plano todo el día y Heart Minutes lo registra "
          "automáticamente. Un paseo rápido, ir en bici al trabajo o subir escaleras cuenta, sin iniciar un entrenamiento.",
    "es-419": "ENTRENAMIENTOS + ACTIVIDAD DIARIA\n"
              "• Entrenamientos: cada entrenamiento cuenta, con el pulso y las zonas en detalle.\n"
              "• Actividad diaria: tu Apple Watch mide el pulso en segundo plano todo el día y Heart Minutes lo registra "
              "automáticamente. Una caminata rápida, ir en bici al trabajo o subir escaleras cuenta, sin iniciar un entrenamiento.",
    "fi": "TREENIT + ARJEN LIIKUNTA\n"
          "• Treenit: jokainen treeni lasketaan, ja syke ja sykealueet näkyvät tarkasti.\n"
          "• Arjen liikunta: Apple Watch mittaa sykettä taustalla koko päivän, ja Heart Minutes kirjaa sen "
          "automaattisesti. Reipas kävely, pyöräily töihin tai portaat lasketaan – ilman treenin aloittamista.",
    "fr": "SÉANCES + ACTIVITÉ DU QUOTIDIEN\n"
          "• Séances : chaque séance compte, avec le pouls et les zones en détail.\n"
          "• Activité du quotidien : votre Apple Watch mesure votre pouls en arrière-plan toute la journée, et Heart Minutes "
          "l'enregistre automatiquement. Marche rapide, vélo pour aller au travail ou escaliers comptent, sans lancer de séance.",
    "he": "אימונים + פעילות יומיומית\n"
          "• אימונים: כל אימון נספר, עם פירוט הדופק והאזורים.\n"
          "• פעילות יומיומית: ה-Apple Watch מודד את הדופק ברקע לאורך כל היום, ו-Heart Minutes רושם אותו אוטומטית. "
          "הליכה מהירה, רכיבה לעבודה או עלייה במדרגות נספרות – בלי להתחיל אימון.",
    "hi": "वर्कआउट + रोज़मर्रा की गतिविधि\n"
          "• वर्कआउट: हर वर्कआउट गिना जाता है, धड़कन और ज़ोन के पूरे विवरण के साथ।\n"
          "• रोज़मर्रा की गतिविधि: आपकी Apple Watch पूरे दिन बैकग्राउंड में धड़कन मापती है, और Heart Minutes उसे अपने-आप "
          "दर्ज करता है। तेज़ चलना, साइकिल से काम पर जाना या सीढ़ियाँ चढ़ना गिना जाता है – वर्कआउट शुरू किए बिना।",
    "hr": "TRENINZI + SVAKODNEVNA AKTIVNOST\n"
          "• Treninzi: svaki trening se broji, s detaljnim pulsom i zonama.\n"
          "• Svakodnevna aktivnost: Apple Watch cijeli dan mjeri puls u pozadini, a Heart Minutes ga automatski bilježi. "
          "Brzo hodanje, biciklom na posao ili penjanje stubama se broji – bez pokretanja treninga.",
    "hu": "EDZÉSEK + HÉTKÖZNAPI MOZGÁS\n"
          "• Edzések: minden edzés számít, részletes pulzussal és zónákkal.\n"
          "• Hétköznapi mozgás: az Apple Watch egész nap a háttérben méri a pulzust, a Heart Minutes pedig automatikusan "
          "rögzíti. A tempós séta, a biciklizés munkába vagy a lépcsőzés is számít – edzés indítása nélkül.",
    "id": "LATIHAN + AKTIVITAS SEHARI-HARI\n"
          "• Latihan: setiap latihan dihitung, dengan detak jantung dan zona secara detail.\n"
          "• Aktivitas sehari-hari: Apple Watch mengukur detak jantung di latar belakang sepanjang hari, dan Heart Minutes "
          "mencatatnya secara otomatis. Jalan cepat, bersepeda ke kantor, atau naik tangga dihitung – tanpa memulai latihan.",
    "it": "ALLENAMENTI + ATTIVITÀ QUOTIDIANA\n"
          "• Allenamenti: ogni allenamento conta, con battito e zone nel dettaglio.\n"
          "• Attività quotidiana: Apple Watch misura il battito in background tutto il giorno e Heart Minutes lo registra "
          "in automatico. Una camminata veloce, andare al lavoro in bici o fare le scale conta, senza avviare un allenamento.",
    "ja": "ワークアウト＋日常の活動\n"
          "• ワークアウト：すべてのワークアウトがカウントされ、心拍数とゾーンを詳しく確認できます。\n"
          "• 日常の活動：Apple Watchは1日中バックグラウンドで心拍数を測り、Heart Minutesが自動で記録します。"
          "早歩き、自転車通勤、階段の上り下りも、ワークアウトを開始しなくてもカウントされます。",
    "ko": "운동 + 일상 활동\n"
          "• 운동: 모든 운동이 계산되며, 심박수와 영역을 자세히 볼 수 있습니다.\n"
          "• 일상 활동: Apple Watch가 하루 종일 백그라운드에서 심박수를 측정하고 Heart Minutes가 자동으로 기록합니다. "
          "빠르게 걷기, 자전거 출근, 계단 오르기도 운동을 시작하지 않아도 계산됩니다.",
    "lt": "TRENIRUOTĖS + KASDIENĖ VEIKLA\n"
          "• Treniruotės: skaičiuojama kiekviena treniruotė, su išsamiu pulsu ir zonomis.\n"
          "• Kasdienė veikla: Apple Watch visą dieną fone matuoja pulsą, o Heart Minutes jį registruoja automatiškai. "
          "Greitas ėjimas, važiavimas dviračiu į darbą ar laiptai skaičiuojami – nepradėjus treniruotės.",
    "ms": "SENAMAN + AKTIVITI HARIAN\n"
          "• Senaman: setiap senaman dikira, dengan nadi dan zon secara terperinci.\n"
          "• Aktiviti harian: Apple Watch mengukur nadi anda di latar belakang sepanjang hari, dan Heart Minutes "
          "merekodkannya secara automatik. Jalan pantas, berbasikal ke tempat kerja atau naik tangga dikira – tanpa memulakan senaman.",
    "nb": "TRENING + HVERDAGSAKTIVITET\n"
          "• Trening: hver treningsøkt teller, med puls og soner i detalj.\n"
          "• Hverdagsaktivitet: Apple Watch måler pulsen i bakgrunnen hele dagen, og Heart Minutes logger den automatisk. "
          "Rask gange, sykkelturen til jobb eller trappene teller – uten at du starter en økt.",
    "nl": "WORKOUTS + DAGELIJKSE ACTIVITEIT\n"
          "• Workouts: elke workout telt, met hartslag en zones in detail.\n"
          "• Dagelijkse activiteit: je Apple Watch meet je hartslag de hele dag op de achtergrond, en Heart Minutes legt "
          "die automatisch vast. Stevig wandelen, naar je werk fietsen of de trap nemen telt – zonder een workout te starten.",
    "pl": "TRENINGI + CODZIENNA AKTYWNOŚĆ\n"
          "• Treningi: liczy się każdy trening, ze szczegółowym tętnem i strefami.\n"
          "• Codzienna aktywność: Apple Watch przez cały dzień mierzy tętno w tle, a Heart Minutes zapisuje je "
          "automatycznie. Szybki marsz, rower do pracy czy schody się liczą – bez włączania treningu.",
    "pt-BR": "TREINOS + ATIVIDADE DO DIA A DIA\n"
             "• Treinos: cada treino conta, com batimentos e zonas em detalhes.\n"
             "• Atividade do dia a dia: o Apple Watch mede seus batimentos em segundo plano o dia todo, e o Heart Minutes "
             "registra isso automaticamente. Caminhada rápida, pedalar até o trabalho ou subir escadas conta – sem iniciar um treino.",
    "pt-PT": "TREINOS + ATIVIDADE DO DIA A DIA\n"
             "• Treinos: cada treino conta, com o pulso e as zonas em pormenor.\n"
             "• Atividade do dia a dia: o Apple Watch mede o pulso em segundo plano durante todo o dia e o Heart Minutes "
             "regista-o automaticamente. Uma caminhada rápida, ir de bicicleta para o trabalho ou subir escadas conta – sem iniciar um treino.",
    "ro": "ANTRENAMENTE + ACTIVITATE ZILNICĂ\n"
          "• Antrenamente: fiecare antrenament contează, cu pulsul și zonele în detaliu.\n"
          "• Activitate zilnică: Apple Watch îți măsoară pulsul în fundal toată ziua, iar Heart Minutes îl înregistrează "
          "automat. Mersul alert, bicicleta până la serviciu sau urcatul scărilor contează – fără să pornești un antrenament.",
    "ru": "ТРЕНИРОВКИ + ПОВСЕДНЕВНАЯ АКТИВНОСТЬ\n"
          "• Тренировки: учитывается каждая тренировка, с подробным пульсом и зонами.\n"
          "• Повседневная активность: Apple Watch весь день измеряет пульс в фоне, а Heart Minutes записывает его "
          "автоматически. Быстрая ходьба, поездка на велосипеде на работу или лестница учитываются – без запуска тренировки.",
    "sk": "TRÉNINGY + BEŽNÁ AKTIVITA\n"
          "• Tréningy: každý tréning sa počíta, s podrobným tepom a zónami.\n"
          "• Bežná aktivita: Apple Watch meria tep na pozadí celý deň a Heart Minutes ho automaticky zaznamenáva. "
          "Svižná chôdza, cesta do práce na bicykli alebo schody sa počítajú – bez spúšťania tréningu.",
    "sl": "VADBE + VSAKODNEVNA AKTIVNOST\n"
          "• Vadbe: vsaka vadba šteje, s podrobnim utripom in conami.\n"
          "• Vsakodnevna aktivnost: Apple Watch ves dan v ozadju meri utrip, Heart Minutes pa ga samodejno beleži. "
          "Hitra hoja, kolesarjenje v službo ali stopnice štejejo – brez začetka vadbe.",
    "sv": "TRÄNINGSPASS + VARDAGSAKTIVITET\n"
          "• Träningspass: varje pass räknas, med puls och zoner i detalj.\n"
          "• Vardagsaktivitet: Apple Watch mäter pulsen i bakgrunden hela dagen, och Heart Minutes loggar den automatiskt. "
          "En rask promenad, cykeln till jobbet eller trapporna räknas – utan att du startar ett pass.",
    "th": "การออกกำลังกาย + กิจกรรมประจำวัน\n"
          "• การออกกำลังกาย: ทุกครั้งนับรวม พร้อมรายละเอียดชีพจรและโซน\n"
          "• กิจกรรมประจำวัน: Apple Watch วัดชีพจรเบื้องหลังตลอดทั้งวัน และ Heart Minutes บันทึกให้อัตโนมัติ "
          "การเดินเร็ว ปั่นจักรยานไปทำงาน หรือขึ้นบันไดก็นับ – โดยไม่ต้องเริ่มการออกกำลังกาย",
    "tr": "ANTRENMANLAR + GÜNLÜK AKTİVİTE\n"
          "• Antrenmanlar: her antrenman sayılır; nabız ve bölgeler ayrıntılı görünür.\n"
          "• Günlük aktivite: Apple Watch gün boyu nabzınızı arka planda ölçer ve Heart Minutes bunu otomatik olarak "
          "kaydeder. Tempolu yürüyüş, işe bisikletle gitmek veya merdiven çıkmak sayılır – antrenman başlatmadan.",
    "uk": "ТРЕНУВАННЯ + ЩОДЕННА АКТИВНІСТЬ\n"
          "• Тренування: враховується кожне тренування, з детальним пульсом і зонами.\n"
          "• Щоденна активність: Apple Watch увесь день вимірює пульс у фоні, а Heart Minutes записує його автоматично. "
          "Швидка ходьба, поїздка на роботу велосипедом чи сходи враховуються – без запуску тренування.",
    "vi": "BUỔI TẬP + HOẠT ĐỘNG HẰNG NGÀY\n"
          "• Buổi tập: mọi buổi tập đều được tính, kèm nhịp tim và vùng chi tiết.\n"
          "• Hoạt động hằng ngày: Apple Watch đo nhịp tim ở chế độ nền suốt cả ngày, và Heart Minutes tự động ghi lại. "
          "Đi bộ nhanh, đạp xe đi làm hay leo cầu thang đều được tính – không cần bắt đầu buổi tập.",
    "zh-Hans": "锻炼 + 日常活动\n"
               "• 锻炼：每次锻炼都会计入，并可详细查看心率和区间。\n"
               "• 日常活动：Apple Watch 全天在后台测量你的心率，Heart Minutes 会自动记录。快走、骑车上班或爬楼梯都会计入——无需开始锻炼。",
    "zh-Hant": "體能訓練 + 日常活動\n"
               "• 體能訓練：每次訓練都會計入，並可詳細查看心率和區間。\n"
               "• 日常活動：Apple Watch 全天在背景測量你的心率，Heart Minutes 會自動記錄。快走、騎車上班或爬樓梯都會計入——無需開始訓練。",
}

if __name__ == "__main__":
    path = pathlib.Path(__file__).with_name("app-store.json")
    data = json.loads(path.read_text())
    assert set(SECTION) == set(data), set(data) ^ set(SECTION)
    for lang, section in SECTION.items():
        parts = data[lang]["description"].split("\n\n")
        parts[1] = section
        text = "\n\n".join(parts)
        assert len(text) <= 4000, (lang, len(text))
        data[lang]["description"] = text
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("updated", len(SECTION), "descriptions; longest", max(len(v["description"]) for v in data.values()))
