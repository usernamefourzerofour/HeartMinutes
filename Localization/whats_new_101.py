"""What's New for version 1.0.1 in every language. Run once: python3 Localization/whats_new_101.py"""
import json
import pathlib

WHATS_NEW = {
    "en": "Clearer App Store page: workouts count, and everyday activity from Apple Watch is logged automatically in the background. New screenshots of the widgets and watch complications. No changes to your data or settings.",
    "ar": "صفحة أوضح في App Store: التمارين تُحتسب، والنشاط اليومي من Apple Watch يُسجَّل تلقائيًا في الخلفية. لقطات شاشة جديدة للأدوات وتعقيدات الساعة. لا تغييرات على بياناتك أو إعداداتك.",
    "bg": "По-ясна страница в App Store: тренировките се броят, а ежедневната активност от Apple Watch се записва автоматично във фонов режим. Нови снимки на уиджетите и усложненията на часовника. Без промени в данните и настройките ви.",
    "ca": "Pàgina de l'App Store més clara: els entrenaments compten i l'activitat diària de l'Apple Watch es registra automàticament en segon pla. Noves captures dels widgets i les complicacions del rellotge. Cap canvi a les teves dades ni a la configuració.",
    "cs": "Přehlednější stránka v App Store: tréninky se počítají a běžná aktivita z Apple Watch se automaticky zaznamenává na pozadí. Nové snímky widgetů a komplikací hodinek. Žádné změny vašich dat ani nastavení.",
    "da": "Tydeligere App Store-side: træning tæller, og hverdagsaktivitet fra Apple Watch logges automatisk i baggrunden. Nye billeder af widgets og urkomplikationer. Ingen ændringer i dine data eller indstillinger.",
    "de": "Klarere App-Store-Seite: Workouts zählen, und Alltagsaktivität von der Apple Watch wird automatisch im Hintergrund erfasst. Neue Bilder der Widgets und Komplikationen. Keine Änderungen an deinen Daten oder Einstellungen.",
    "el": "Πιο σαφής σελίδα στο App Store: οι προπονήσεις μετράνε και η καθημερινή δραστηριότητα από το Apple Watch καταγράφεται αυτόματα στο παρασκήνιο. Νέες εικόνες των widget και των επιπλοκών του ρολογιού. Καμία αλλαγή στα δεδομένα ή τις ρυθμίσεις σας.",
    "es": "Página de App Store más clara: los entrenamientos cuentan y la actividad diaria del Apple Watch se registra automáticamente en segundo plano. Nuevas capturas de los widgets y las complicaciones del reloj. Sin cambios en tus datos ni ajustes.",
    "es-419": "Página de App Store más clara: los entrenamientos cuentan y la actividad diaria del Apple Watch se registra automáticamente en segundo plano. Nuevas capturas de los widgets y las complicaciones del reloj. Sin cambios en tus datos ni configuración.",
    "fi": "Selkeämpi App Store -sivu: treenit lasketaan, ja Apple Watchin arjen liikunta kirjautuu automaattisesti taustalla. Uudet kuvat widgeteistä ja kellon komplikaatioista. Ei muutoksia tietoihisi tai asetuksiisi.",
    "fr": "Page App Store plus claire : les séances comptent et l'activité du quotidien de l'Apple Watch est enregistrée automatiquement en arrière-plan. Nouvelles captures des widgets et des complications. Aucun changement de vos données ou réglages.",
    "he": "עמוד App Store ברור יותר: אימונים נספרים, ופעילות יומיומית מה-Apple Watch נרשמת אוטומטית ברקע. צילומי מסך חדשים של הווידג'טים והתוספות בשעון. ללא שינויים בנתונים או בהגדרות.",
    "hi": "App Store पेज अब और साफ़: वर्कआउट गिने जाते हैं, और Apple Watch से रोज़मर्रा की गतिविधि बैकग्राउंड में अपने-आप दर्ज होती है। विजेट और घड़ी की कॉम्प्लिकेशन के नए स्क्रीनशॉट। आपके डेटा या सेटिंग में कोई बदलाव नहीं।",
    "hr": "Jasnija stranica u App Storeu: treninzi se broje, a svakodnevna aktivnost s Apple Watcha bilježi se automatski u pozadini. Nove slike widgeta i komplikacija sata. Bez promjena u vašim podacima ili postavkama.",
    "hu": "Áttekinthetőbb App Store-oldal: az edzések számítanak, a hétköznapi mozgást pedig az Apple Watch automatikusan rögzíti a háttérben. Új képek a widgetekről és az óra komplikációiról. Az adataid és beállításaid nem változnak.",
    "id": "Halaman App Store lebih jelas: latihan dihitung, dan aktivitas sehari-hari dari Apple Watch tercatat otomatis di latar belakang. Tangkapan layar baru untuk widget dan komplikasi jam. Tidak ada perubahan pada data atau pengaturan Anda.",
    "it": "Pagina dell'App Store più chiara: gli allenamenti contano e l'attività quotidiana di Apple Watch viene registrata in automatico in background. Nuove immagini dei widget e delle complicazioni. Nessuna modifica ai tuoi dati o alle impostazioni.",
    "ja": "App Storeのページをわかりやすくしました：ワークアウトはもちろん、Apple Watchの日常の活動もバックグラウンドで自動的に記録されます。ウィジェットとコンプリケーションの新しいスクリーンショット。データや設定に変更はありません。",
    "ko": "더 명확해진 App Store 페이지: 운동은 물론 Apple Watch의 일상 활동도 백그라운드에서 자동으로 기록됩니다. 위젯과 시계 컴플리케이션의 새 스크린샷. 데이터나 설정은 바뀌지 않습니다.",
    "lt": "Aiškesnis App Store puslapis: treniruotės skaičiuojamos, o kasdienė veikla iš Apple Watch automatiškai registruojama fone. Nauji valdiklių ir laikrodžio komplikacijų vaizdai. Jūsų duomenys ir nustatymai nesikeičia.",
    "ms": "Halaman App Store lebih jelas: senaman dikira, dan aktiviti harian daripada Apple Watch direkod secara automatik di latar belakang. Tangkapan skrin baharu bagi widget dan komplikasi jam. Tiada perubahan pada data atau tetapan anda.",
    "nb": "Tydeligere App Store-side: trening teller, og hverdagsaktivitet fra Apple Watch logges automatisk i bakgrunnen. Nye bilder av widgetene og urkomplikasjonene. Ingen endringer i dataene eller innstillingene dine.",
    "nl": "Duidelijkere App Store-pagina: workouts tellen, en dagelijkse activiteit van Apple Watch wordt automatisch op de achtergrond vastgelegd. Nieuwe afbeeldingen van de widgets en complicaties. Geen wijzigingen in je gegevens of instellingen.",
    "pl": "Czytelniejsza strona w App Store: treningi się liczą, a codzienna aktywność z Apple Watch zapisuje się automatycznie w tle. Nowe zrzuty widżetów i komplikacji zegarka. Bez zmian w Twoich danych i ustawieniach.",
    "pt-BR": "Página da App Store mais clara: os treinos contam, e a atividade do dia a dia do Apple Watch é registrada automaticamente em segundo plano. Novas imagens dos widgets e das complicações. Nenhuma mudança nos seus dados ou ajustes.",
    "pt-PT": "Página da App Store mais clara: os treinos contam e a atividade do dia a dia do Apple Watch é registada automaticamente em segundo plano. Novas imagens dos widgets e das complicações. Sem alterações aos seus dados ou definições.",
    "ro": "Pagină App Store mai clară: antrenamentele contează, iar activitatea zilnică de pe Apple Watch se înregistrează automat în fundal. Capturi noi ale widgeturilor și complicațiilor ceasului. Fără schimbări ale datelor sau setărilor tale.",
    "ru": "Более понятная страница в App Store: тренировки учитываются, а повседневная активность с Apple Watch записывается автоматически в фоне. Новые снимки виджетов и усложнений часов. Ваши данные и настройки не меняются.",
    "sk": "Prehľadnejšia stránka v App Store: tréningy sa počítajú a bežná aktivita z Apple Watch sa automaticky zaznamenáva na pozadí. Nové snímky widgetov a komplikácií hodiniek. Žiadne zmeny vašich údajov ani nastavení.",
    "sl": "Jasnejša stran v App Storu: vadbe štejejo, vsakodnevna aktivnost z ure Apple Watch pa se samodejno beleži v ozadju. Nove slike pripomočkov in zapletov ure. Brez sprememb vaših podatkov ali nastavitev.",
    "sv": "Tydligare App Store-sida: träningspass räknas, och vardagsaktivitet från Apple Watch loggas automatiskt i bakgrunden. Nya bilder på widgetarna och urkomplikationerna. Inga ändringar i dina data eller inställningar.",
    "th": "หน้า App Store ที่ชัดเจนขึ้น: การออกกำลังกายนับรวม และกิจกรรมประจำวันจาก Apple Watch ถูกบันทึกอัตโนมัติเบื้องหลัง ภาพหน้าจอใหม่ของวิดเจ็ตและคอมพลิเคชั่นบนนาฬิกา ไม่มีการเปลี่ยนแปลงข้อมูลหรือการตั้งค่าของคุณ",
    "tr": "Daha anlaşılır App Store sayfası: antrenmanlar sayılır ve Apple Watch'tan gelen günlük aktivite arka planda otomatik olarak kaydedilir. Widget'ların ve saat komplikasyonlarının yeni görüntüleri. Verilerinizde veya ayarlarınızda değişiklik yok.",
    "uk": "Зрозуміліша сторінка в App Store: тренування враховуються, а щоденна активність з Apple Watch записується автоматично у фоні. Нові знімки віджетів і ускладнень годинника. Ваші дані й налаштування не змінюються.",
    "vi": "Trang App Store rõ ràng hơn: buổi tập được tính, và hoạt động hằng ngày từ Apple Watch được tự động ghi lại ở chế độ nền. Ảnh chụp màn hình mới của tiện ích và tổ hợp trên đồng hồ. Không thay đổi dữ liệu hay cài đặt của bạn.",
    "zh-Hans": "App Store 页面更清晰：锻炼会计入，Apple Watch 记录的日常活动也会在后台自动记录。新增小组件和表盘复杂功能的截图。你的数据和设置不变。",
    "zh-Hant": "App Store 頁面更清楚：體能訓練會計入，Apple Watch 的日常活動也會在背景自動記錄。新增小工具和錶面複雜功能的截圖。你的資料和設定不變。",
}

if __name__ == "__main__":
    path = pathlib.Path(__file__).with_name("app-store.json")
    data = json.loads(path.read_text())
    assert set(WHATS_NEW) == set(data), set(data) ^ set(WHATS_NEW)
    for lang, text in WHATS_NEW.items():
        assert len(text) <= 4000
        data[lang]["whats_new"] = text
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("updated", len(WHATS_NEW), "languages")
