# daakLOLILE — Türkçe

daakLOLILE; Windows üzerinde çalışan Tor middle/non-exit relay, Snowflake, bilgisayar donanımı ve güvenli güç modlarını tek panelden yönetir. Küçük bir Windows masaüstü bileşeni ve Tailscale üzerinden çalışan macOS üst menü uygulaması içerir.

## Özellikler

- Tor trafiği, bootstrap, ORPort erişimi ve consensus durumu
- Snowflake bağlantı ve trafik sayaçları
- CPU, GPU, RAM, disk, ağ ve işlem kullanımları
- Sensörden alınabilen sıcaklık ve güç değerleri
- Tahmini toplam priz tüketimi ile günlük/aylık kWh takibi
- Kullanıcı giriş yapmasa da çalışan Windows görevleri
- Yalnızca localhost üzerinden değiştirilebilen relay ayarları
- Gece `00:00–08:00` arasında otomatik tasarruf, gündüz dengeli mod
- Tailscale üzerinden otomatik, tasarruf, dengeli ve yüksek performans geçişi
- Tasarruf modunda bile uyku, hibernasyon ve ağ kesintisinin kapalı tutulması
- Tailscale adres aralıklarıyla sınırlı uzaktan panel

## Güvenlik

daakLOLILE bir exit relay kurmaz. Tor yapılandırmanızda aşağıdaki satırların bulunması önerilir:

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

Uygulama açıldığında Windows bilgisayarının Tailscale IP'sini yazın. Mac uygulaması verileri okur ve yalnızca önceden tanımlı güç modları arasında geçiş yapabilir; Mac üzerinde relay çalıştırmaz ve Tor ayarlarını değiştiremez.

## Güvenli güç modları

- **Otomatik:** Varsayılan olarak `00:00–08:00` tasarruf, diğer saatlerde dengeli.
- **Gece tasarrufu:** CPU üst sınırı %60, destekleniyorsa boost kapalı, ekran 10 dakikada kapanır.
- **Dengeli:** Günlük kullanım için tam CPU aralığı.
- **Yüksek performans:** Tam CPU ve boost, daha uzun ekran süresi.

Her modda Windows uyku, hibernasyon ve hibrit uyku kapalıdır. Tor, Snowflake, Tailscale, Chrome Remote Desktop, RDP, SMB disk paylaşımı ve Syncthing ayarlarına dokunulmaz. Güç yöneticisi kullanıcı girişi olmadan `SYSTEM` olarak çalışır.

## Güvenli RAM bakımı

Windows boş RAM'i hız kazandıran bir önbellek olarak kullanır; bu nedenle daakLOLILE her gün RAM'i körlemesine boşaltmaz. Kullanıcı girişi gerektirmeyen görev her gün `04:30`'da kontrol yapar. Otomatik müdahale ancak kullanım en az `%85` ve boş fiziksel bellek en fazla `2 GB` olduğunda gerçekleşir.

Bakım gerektiğinde yalnızca daakLOLILE paneli ve donanım izleyicisinin yardımcı süreçleri küçültülür. Tor, Snowflake, Tailscale, Chrome Remote Desktop, RDP, SMB, Syncthing, diğer uygulamalar ve Windows önbelleği hedeflenmez. Yerel panelden veya Tailscale üzerinden elle güvenli bakım da başlatılabilir.

## Güç tüketimi

Güç kaynağındaki 650 W gibi değerler anlık tüketim değil, azami kapasitedir. daakLOLILE erişebildiği bileşen sensörlerini kullanır; eksik CPU/sistem/PSU değerlerini tahmin eder ve toplamı açıkça tahmini olarak işaretler.

Gerçek priz tüketimi için yerel API sunan güvenilir bir akıllı priz veya harici güç ölçer gerekir.

## Kaldırma

Yönetici PowerShell:

```powershell
.\windows\uninstall.ps1
```

Bu işlem Tor, Snowflake ve Tailscale'i kaldırmaz.
