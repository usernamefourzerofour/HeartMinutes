"""What's New for version 1.0.2 in every language. Run once: python3 Localization/whats_new_102.py"""
import json
import pathlib

WHATS_NEW = {
    "en": "New App Store screenshot of the watch complications and the watch app together. No changes to the app.",
    "ar": "لقطة شاشة جديدة في App Store تعرض تعقيدات الساعة وتطبيق الساعة معًا. لا تغييرات على التطبيق.",
    "bg": "Нова снимка в App Store с усложненията и приложението за часовника заедно. Без промени в приложението.",
    "ca": "Nova captura a l'App Store amb les complicacions i l'app del rellotge juntes. Cap canvi a l'app.",
    "cs": "Nový snímek v App Store s komplikacemi a aplikací hodinek pohromadě. Žádné změny v aplikaci.",
    "da": "Nyt App Store-billede med urkomplikationerne og ur-appen sammen. Ingen ændringer i appen.",
    "de": "Neues App-Store-Bild mit den Komplikationen und der Watch-App zusammen. Keine Änderungen an der App.",
    "el": "Νέα εικόνα στο App Store με τις επιπλοκές και την εφαρμογή του ρολογιού μαζί. Καμία αλλαγή στην εφαρμογή.",
    "es": "Nueva captura en App Store con las complicaciones y la app del reloj juntas. Sin cambios en la app.",
    "es-419": "Nueva captura en App Store con las complicaciones y la app del reloj juntas. Sin cambios en la app.",
    "fi": "Uusi App Store -kuva, jossa kellon komplikaatiot ja kelloappi ovat yhdessä. Ei muutoksia appiin.",
    "fr": "Nouvelle capture App Store avec les complications et l'app de la montre réunies. Aucun changement dans l'app.",
    "he": "צילום מסך חדש ב-App Store עם התוספות ואפליקציית השעון יחד. ללא שינויים באפליקציה.",
    "hi": "App Store में नया स्क्रीनशॉट, जिसमें घड़ी की कॉम्प्लिकेशन और वॉच ऐप एक साथ हैं। ऐप में कोई बदलाव नहीं।",
    "hr": "Nova slika u App Storeu s komplikacijama i aplikacijom sata zajedno. Bez promjena u aplikaciji.",
    "hu": "Új App Store-kép, amelyen az óra komplikációi és az óraapp együtt látható. Az app nem változott.",
    "id": "Tangkapan layar App Store baru dengan komplikasi dan app jam sekaligus. Tidak ada perubahan pada app.",
    "it": "Nuova immagine nell'App Store con le complicazioni e l'app per Apple Watch insieme. Nessuna modifica all'app.",
    "ja": "コンプリケーションとWatchアプリを一緒に紹介する新しいApp Storeスクリーンショット。アプリ自体に変更はありません。",
    "ko": "컴플리케이션과 Watch 앱을 함께 보여 주는 새 App Store 스크린샷. 앱은 바뀌지 않았습니다.",
    "lt": "Nauja App Store nuotrauka su laikrodžio komplikacijomis ir programa kartu. Programa nepasikeitė.",
    "ms": "Tangkapan skrin App Store baharu dengan komplikasi dan app jam bersama-sama. Tiada perubahan pada app.",
    "nb": "Nytt App Store-bilde med urkomplikasjonene og klokkeappen sammen. Ingen endringer i appen.",
    "nl": "Nieuwe App Store-afbeelding met de complicaties en de Watch-app samen. Geen wijzigingen in de app.",
    "pl": "Nowy zrzut w App Store z komplikacjami i aplikacją na zegarek razem. Bez zmian w aplikacji.",
    "pt-BR": "Nova imagem na App Store com as complicações e o app do relógio juntos. Nenhuma mudança no app.",
    "pt-PT": "Nova imagem na App Store com as complicações e a app do relógio juntas. Sem alterações à app.",
    "ro": "Captură nouă în App Store cu complicațiile și aplicația ceasului împreună. Fără schimbări în aplicație.",
    "ru": "Новый снимок в App Store с усложнениями и приложением для часов вместе. Приложение не изменилось.",
    "sk": "Nový snímok v App Store s komplikáciami a aplikáciou hodiniek spolu. Žiadne zmeny v aplikácii.",
    "sl": "Nova slika v App Storu z zapleti in aplikacijo za uro skupaj. Brez sprememb aplikacije.",
    "sv": "Ny App Store-bild med urkomplikationerna och klockappen tillsammans. Inga ändringar i appen.",
    "th": "ภาพหน้าจอใหม่ใน App Store แสดงคอมพลิเคชั่นและแอปบนนาฬิกาพร้อมกัน ไม่มีการเปลี่ยนแปลงในแอป",
    "tr": "Saat komplikasyonlarını ve saat uygulamasını birlikte gösteren yeni App Store görüntüsü. Uygulamada değişiklik yok.",
    "uk": "Новий знімок в App Store з ускладненнями та застосунком для годинника разом. Застосунок не змінився.",
    "vi": "Ảnh chụp màn hình App Store mới hiển thị tổ hợp và ứng dụng đồng hồ cùng nhau. Ứng dụng không thay đổi.",
    "zh-Hans": "新的 App Store 截图，同时展示表盘复杂功能和手表 App。App 本身没有变化。",
    "zh-Hant": "新的 App Store 截圖，同時展示錶面複雜功能和手錶 App。App 本身沒有變化。",
}

if __name__ == "__main__":
    path = pathlib.Path(__file__).with_name("app-store.json")
    data = json.loads(path.read_text())
    assert set(WHATS_NEW) == set(data), set(data) ^ set(WHATS_NEW)
    for lang, text in WHATS_NEW.items():
        data[lang]["whats_new"] = text
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("updated", len(WHATS_NEW), "languages")
