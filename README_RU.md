# Flowgate

**Контроллер сетевого потока (Менеджер DNS и прокси)**

Flowgate — это современный инструмент командной строки (CLI) и веб-интерфейс, предназначенный для управления вашей инфраструктурой сетевого потока. Он объединяет настройку прокси-серверов уровня 4/7 (Angie или Nginx) и DNS-серверов (Blocky или AdGuardHome), упрощая маршрутизацию трафика, управление локальными сервисами и обход региональных ограничений для ИИ-сервисов.

## Возможности

*   **Единое управление:** Управляйте прокси и DNS-сервером из одного интерфейса.
*   **Проксирование ИИ-сервисов:** Предварительно настроенный список популярных ИИ-сервисов (OpenAI, Google Gemini, Claude и др.) для легкого проксирования и обхода ограничений.
*   **Обнаружение локальных сервисов:** Легко публикуйте локальные приложения через обратный прокси с автоматическим созданием DNS-записей.
*   **Веб-панель:** Удобный веб-интерфейс для управления доменами и сервисами.
*   **Автоматический SSL:** Автоматическое управление сертификатами через нативный ACME (для Angie) или Certbot (для Nginx).
*   **Поддержка 30+ дистрибутивов:** Работает на Debian, Ubuntu, Fedora, Arch, Alpine, openSUSE, Gentoo, Void и многих других.
*   **Универсальная init-система:** Поддержка systemd, OpenRC, SysVinit, runit и s6.
*   **Гибкая архитектура:** Поддержка нескольких бэкендов:
    *   **Прокси:** Angie или Nginx
    *   **DNS:** Blocky или AdGuardHome

## Установка

Flowgate поддерживает несколько комбинаций бэкендов. Выберите в зависимости от ваших потребностей:

| Комбинация | Подходит для |
|------------|--------------|
| **Angie + Blocky** | Лучшая производительность, нативный ACME SSL, не нужен Certbot (по умолчанию) |
| **Angie + AdGuardHome** | Полнофункциональный: нативный SSL + веб-интерфейс DNS |
| **Nginx + Blocky** | Стандартный Nginx, использует Certbot для SSL |
| **Nginx + AdGuardHome** | Стандартный Nginx + веб-интерфейс для управления DNS |

### Вариант 1: Debian/Ubuntu (рекомендуется)

Скачайте пакеты из [Releases](https://github.com/crim50n/flowgate/releases):

**Angie + Blocky (по умолчанию):**
```bash
# Сначала добавьте репозиторий Angie (см. https://angie.software/ru/install/)
sudo apt install ./flowgate_*.deb ./blocky_*.deb angie angie-module-stream
sudo flowgate init
```

**Angie + AdGuardHome:**
```bash
# Сначала добавьте репозиторий Angie (см. https://angie.software/ru/install/)
sudo apt install ./flowgate_*.deb ./adguardhome_*.deb angie angie-module-stream
sudo flowgate init
```

**Nginx + Blocky:**
```bash
sudo apt install ./flowgate_*.deb ./blocky_*.deb
sudo flowgate init
```

**Nginx + AdGuardHome:**
```bash
sudo apt install ./flowgate_*.deb ./adguardhome_*.deb
sudo flowgate init
```

### Вариант 2: Из исходного кода

**Шаг 1:** Установите базовые зависимости:

```bash
# Debian/Ubuntu
sudo apt install -y python3 python3-yaml

# Fedora/RHEL
sudo dnf install -y python3 python3-pyyaml

# Arch Linux
sudo pacman -S python python-yaml

# Alpine Linux
apk add python3 py3-yaml
```

**Шаг 2:** Установите выбранный прокси-сервер:

*Angie (Certbot не нужен — есть нативный ACME):*
```bash
# Настройка репозитория: https://angie.software/ru/install/
# Debian/Ubuntu
sudo apt install -y angie angie-module-stream

# Fedora/RHEL
sudo dnf install -y angie angie-mod-stream

# Alpine Linux
apk add angie angie-mod-stream
```

*Nginx:*
```bash
# Debian/Ubuntu
sudo apt install -y nginx libnginx-mod-stream certbot python3-certbot-nginx

# Fedora/RHEL
sudo dnf install -y nginx nginx-mod-stream certbot python3-certbot-nginx

# Arch Linux
sudo pacman -S nginx certbot certbot-nginx

# Alpine Linux
apk add nginx nginx-mod-stream certbot certbot-nginx
```

**Шаг 3:** Установите выбранный DNS-сервер:

*Blocky:*
```bash
# Соберите из исходников или скачайте бинарник с https://github.com/0xERR0R/blocky/releases
sudo cp blocky /usr/bin/
```

*AdGuardHome:*
```bash
# Скачайте с https://github.com/AdguardTeam/AdGuardHome/releases
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
```

**Шаг 4:** Установите Flowgate:

```bash
sudo make install          # Только CLI
sudo make install WEB=1    # CLI + Веб-интерфейс
```

## Использование

### CLI (`flowgate`)

Команда `flowgate` является основным способом взаимодействия с системой.

**Первоначальная настройка:**
```bash
# Инициализировать Flowgate и применить базовую конфигурацию
sudo flowgate init
```

**Установить основной DNS-домен (DoH/DoT):**
```bash
sudo flowgate dns dns.mydomain.com
```

**Проверка статуса:**
```bash
sudo flowgate status
```

**Добавить сквозной прокси (например, для ИИ-сервисов):**
```bash
sudo flowgate add example.com
```

**Опубликовать локальный сервис (Обратный прокси):**
```bash
# Сопоставляет app.local -> 127.0.0.1:8080
sudo flowgate service app.local 8080

# Сопоставляет app.local -> 192.168.1.50:3000
sudo flowgate service app.local 3000 --ip 192.168.1.50
```

**Удалить домен:**
```bash
sudo flowgate remove example.com
```

**Принудительная синхронизация конфигурации:**
```bash
sudo flowgate sync
```

> **Примечание:** Команды `add`, `service` и `dns` автоматически запускают `sync` после изменений.

**Управление сервисами:**
```bash
# Запустить/остановить/перезапустить все сервисы
sudo flowgate start
sudo flowgate stop
sudo flowgate restart
```

**Диагностика системы:**
```bash
# Проверить состояние системы и получить инструкции по установке
sudo flowgate doctor
sudo flowgate doctor -v  # подробный режим
```

**Включить авто-синхронизацию (рекомендуется):**
```bash
# Автоматически синхронизировать при изменении /etc/flowgate/flowgate.yaml
sudo systemctl enable --now flowgate-sync.path
```

### Веб-интерфейс

Доступ к веб-интерфейсу по адресу `http://localhost:5000`

```bash
# Запустить сервис
sudo systemctl start flowgate-web

# Включить автозапуск при загрузке
sudo systemctl enable flowgate-web
```

## Конфигурация

Основной файл конфигурации находится по адресу `/etc/flowgate/flowgate.yaml`.

**Пример `flowgate.yaml`:**

```yaml
settings:
  proxy_ip: "0.0.0.0" # Публичный IP вашего прокси-сервера

domains:
  # Сквозные прокси (SNI Proxy)
  openai.com: {type: proxy}
  anthropic.com: {type: proxy}

  # Локальные сервисы (Обратный прокси)
  my-app.local:
    type: service
    ip: 127.0.0.1
    port: 8080
```

## Docker

Flowgate доступен в GitHub Container Registry. Он поддерживает различные комбинации прокси и DNS-серверов.

**Доступные теги:**
*   `angie-blocky`: **Angie + Blocky** (По умолчанию). Лучшая производительность. Angie автоматически управляет SSL через ACME. Blocky легковесен и настраивается через файлы.
*   `angie-adguardhome`: **Angie + AdGuardHome**. Добавляет веб-интерфейс для управления DNS (AdGuardHome).
*   `nginx-blocky`: **Nginx + Blocky**. Использует стандартный Nginx. Управление SSL осуществляется через Certbot.
*   `nginx-adguardhome`: **Nginx + AdGuardHome**. Стандартный Nginx с веб-интерфейсом AdGuardHome.

**Запуск (По умолчанию - Angie + Blocky):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 853:853 \
  -p 5000:5000 \
  -v flowgate_config:/etc/flowgate \
  -v angie_state:/var/lib/angie \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  ghcr.io/crim50n/flowgate:angie-blocky
```

**Запуск (Angie + AdGuardHome):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 853:853 \
  -p 5000:5000 -p 3000:3000 \
  -v flowgate_config:/etc/flowgate \
  -v angie_state:/var/lib/angie \
  -v adguard_work:/opt/AdGuardHome \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  ghcr.io/crim50n/flowgate:angie-adguardhome
```

**Запуск (Nginx + Blocky):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 853:853 \
  -p 5000:5000 \
  -v flowgate_config:/etc/flowgate \
  -v letsencrypt_certs:/etc/letsencrypt \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  ghcr.io/crim50n/flowgate:nginx-blocky
```

**Запуск (Nginx + AdGuardHome):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 853:853 \
  -p 5000:5000 -p 3000:3000 \
  -v flowgate_config:/etc/flowgate \
  -v letsencrypt_certs:/etc/letsencrypt \
  -v adguard_work:/opt/AdGuardHome \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  ghcr.io/crim50n/flowgate:nginx-adguardhome
```

> **Примечание:** Если вам нужен внешний доступ к DNS, добавьте `-p 53:53/udp` к команде запуска.

**Детали конфигурации:**

*   **Порты:**
    *   `53/udp`: DNS-сервис (Опционально, для внешнего доступа к DNS).
    *   `80/tcp`: HTTP (Обязательно для ACME-проверок и редиректов).
    *   `443/tcp`: HTTPS (Обязательно для SNI-прокси и обратного прокси).
    *   `853/tcp`: DNS over TLS (Опционально, для DoT).
    *   `5000/tcp`: Веб-панель Flowgate.
    *   `3000/tcp`: Веб-панель AdGuardHome (только для вариантов с AGH).

*   **Тома (Volumes):**
    *   `/etc/flowgate`: Хранит основную конфигурацию (`flowgate.yaml`) и сгенерированные конфиги прокси.
    *   `/var/lib/angie`: Хранит состояние Angie, включая **SSL-сертификаты ACME** (только для вариантов с Angie).
    *   `/etc/letsencrypt`: Хранит SSL-сертификаты Certbot (только для вариантов с Nginx).
    *   `/opt/AdGuardHome`: Хранит конфигурацию и данные AdGuardHome (только для вариантов с AGH).

*   **Переменные окружения:**
    *   `ENABLE_WEB_UI`: Установите в `true`, чтобы включить веб-интерфейс Flowgate.
    *   `PROXY_IP`: Публичный IP-адрес сервера. Установите в `auto` для автоопределения (по умолчанию) или укажите вручную.
    *   `DNS_DOMAIN`: (Опционально) Доменное имя для DoH/DoT (например, `dns.example.com`).

**Сборка из исходного кода:**
```bash
# По умолчанию (Angie + Blocky)
docker build -t flowgate -f Dockerfile.angie-blocky .

# Другие варианты
docker build -t flowgate:agh -f Dockerfile.angie-adguardhome .
```

## Архитектура

Flowgate управляет конфигурацией для:

**Слой прокси (Angie/Nginx):**
- **Модуль Stream:** Сквозной SNI для HTTPS трафика (ИИ-сервисы)
- **Модуль HTTP:** Обратный прокси с терминацией SSL (локальные сервисы)

**Слой DNS (Blocky/AdGuardHome):**
- Разрешает DNS-запросы для управляемых доменов
- Направляет домены на IP вашего прокси для перехвата трафика

## Лицензия

GPL-3.0 - см. файл [LICENSE](LICENSE) для подробностей
