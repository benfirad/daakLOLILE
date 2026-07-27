# RelayWatch — Türkçe

RelayWatch; Windows üzerinde çalışan Tor middle/non-exit relay, Snowflake ve bilgisayar donanımını tek panelden izler. Küçük bir Windows masaüstü bileşeni ve Tailscale üzerinden çalışan salt okunur macOS üst menü uygulaması içerir.

## Özellikler

- Tor trafiği, bootstrap, ORPort erişimi ve consensus durumu
- Snowflake bağlantı ve trafik sayaçları
- CPU, GPU, RAM, disk, ağ ve işlem kullanımları
- Sensörden alınabilen sıcaklık ve güç değerleri
- Tahmini toplam priz tüketimi ile günlük/aylık kWh takibi
- Kullanıcı giriş yapmasa da çalışan Windows görevleri
- Yalnızca localhost üzerinden değiştirilebilen relay ayarları
- Tailscale adres aralıklarıyla sınırlı uzaktan panel

## Güvenlik

RelayWatch bir exit relay kurmaz. Tor yapılandırmanızda aşağıdaki satırların bulunması önerilir:

```text
SocksPort 0
ExitRelay 0
ExitPolicy reject *:*
```

Paneli doğrudan internete açmayın. Kurulum aracı panel güvenlik duvarı kuralını yalnızca Tailscale IPv4/IPv6 aralıklarıyla sınırlar. Tor kimlik dosyaları, kontrol çerezleri, kurtarma ifadeleri veya Tailscale anahtarları repoya eklenmemelidir.

## Windows kurulumu

Önce Windows üzerinde çalışan bir Tor relay ve Node.js 22+ bulunmalıdır. PowerShell'i yönetici olarak açın:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\install.ps1 -InstallWidget
```

Yerel panel:

```text
http://127.0.0.1:17657
```

Mac veya başka bir tailnet cihazından:

```text
http://WINDOWS_TAILSCALE_IP:17657
```

## macOS uygulaması

`macos` klasörünü Mac'e kopyalayın ve Terminal'de:

```zsh
xcode-select --install
zsh build.command
```

Uygulama açıldığında Windows bilgisayarının Tailscale IP'sini yazın. Mac uygulaması yalnızca veri okur; Mac üzerinde relay çalıştırmaz.

## Güç tüketimi

Güç kaynağındaki 650 W gibi değerler anlık tüketim değil, azami kapasitedir. RelayWatch erişebildiği bileşen sensörlerini kullanır; eksik CPU/sistem/PSU değerlerini tahmin eder ve toplamı açıkça tahmini olarak işaretler.

Gerçek priz tüketimi için yerel API sunan güvenilir bir akıllı priz veya harici güç ölçer gerekir.

## Kaldırma

Yönetici PowerShell:

```powershell
.\windows\uninstall.ps1
```

Bu işlem Tor, Snowflake ve Tailscale'i kaldırmaz.
