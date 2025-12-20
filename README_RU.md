# Flowgate

**Контроллер сетевого потока (Менеджер DNS и прокси)**

Flowgate — это современный инструмент командной строки (CLI) и веб-интерфейс, предназначенный для управления вашей инфраструктурой сетевого потока. Он объединяет настройку прокси-серверов уровня 4/7 (Nginx или Angie) и DNS-серверов (Blocky или AdGuardHome), упрощая маршрутизацию трафика, управление локальными сервисами и обход региональных ограничений для ИИ-сервисов.

## Возможности

*   **Единое управление:** Управляйте прокси и DNS-сервером из одного интерфейса.
*   **Проксирование ИИ-сервисов:** Предварительно настроенный список популярных ИИ-сервисов (OpenAI, Google Gemini, Claude и др.) для легкого проксирования и обхода ограничений.
*   **Обнаружение локальных сервисов:** Легко публикуйте локальные приложения через обратный прокси с автоматическим созданием DNS-записей.
*   **Веб-панель:** Удобный веб-интерфейс для управления доменами и сервисами.
*   **Автоматический SSL:** Автоматическое управление сертификатами через Certbot (для Nginx) или нативный ACME (для Angie).
*   **Гибкая архитектура:** Поддержка нескольких бэкендов:
    *   **Прокси:** Nginx или Angie
    *   **DNS:** Blocky или AdGuardHome

## Установка

### Предварительные требования

Flowgate требует наличия следующих компонентов:
- **DNS-сервер:** Blocky или AdGuardHome
- **Прокси-сервер:** Nginx или Angie

Их можно установить через менеджер пакетов вашего дистрибутива.

### Вариант 1: Из исходного кода

```bash
sudo make install          # Только CLI
sudo make install WEB=1    # CLI + Веб-интерфейс
```

### Вариант 2: Docker

Flowgate доступен на Docker Hub как `crims0n/flowgate`. Он поддерживает различные комбинации прокси и DNS-серверов.

**Доступные теги:**
*   `latest`, `angie-blocky`: **Angie + Blocky** (По умолчанию). Лучшая производительность. Angie автоматически управляет SSL через ACME. Blocky легковесен и настраивается через файлы.
*   `angie-adguardhome`: **Angie + AdGuardHome**. Добавляет веб-интерфейс для управления DNS (AdGuardHome).
*   `nginx-blocky`: **Nginx + Blocky**. Использует стандартный Nginx. Управление SSL осуществляется через Certbot.
*   `nginx-adguardhome`: **Nginx + AdGuardHome**. Стандартный Nginx с веб-интерфейсом AdGuardHome.

**Запуск (По умолчанию - Angie + Blocky):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 53:53/udp \
  -p 5000:5000 \
  -v flowgate_config:/etc/flowgate \
  -v angie_state:/var/lib/angie \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  crims0n/flowgate:latest
```

**Запуск (Вариант с AdGuardHome):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 53:53/udp \
  -p 5000:5000 -p 3000:3000 \
  -v flowgate_config:/etc/flowgate \
  -v angie_state:/var/lib/angie \
  -v adguard_work:/opt/AdGuardHome \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  crims0n/flowgate:angie-adguardhome
```

**Запуск (Nginx + Blocky):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 53:53/udp \
  -p 5000:5000 \
  -v flowgate_config:/etc/flowgate \
  -v letsencrypt_certs:/etc/letsencrypt \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  crims0n/flowgate:nginx-blocky
```

**Запуск (Nginx + AdGuardHome):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 53:53/udp \
  -p 5000:5000 -p 3000:3000 \
  -v flowgate_config:/etc/flowgate \
  -v letsencrypt_certs:/etc/letsencrypt \
  -v adguard_work:/opt/AdGuardHome \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  crims0n/flowgate:nginx-adguardhome
```

**Детали конфигурации:**

*   **Порты:**
    *   `53/udp`: DNS-сервис (Обязательно).
    *   `80/tcp`: HTTP (Обязательно для ACME-проверок и редиректов).
    *   `443/tcp`: HTTPS (Обязательно для SNI-прокси и обратного прокси).
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
Если вы предпочитаете собирать локально:
```bash
# По умолчанию (Angie + Blocky)
docker build -t flowgate -f Dockerfile.angie-blocky .

# Другие варианты
docker build -t flowgate:agh -f Dockerfile.angie-adguardhome .
```

## Использование

### CLI (`flowgate`)

Команда `flowgate` является основным способом взаимодействия с системой.

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

**Установить основной DNS-домен (DoH/DoT):**
```bash
sudo flowgate dns dns.mydomain.com
```

**Удалить домен:**
```bash
sudo flowgate remove example.com
```

**Принудительная синхронизация конфигурации:**
```bash
sudo flowgate sync
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

## Архитектура

Flowgate управляет конфигурацией для:

**Слой прокси (Nginx/Angie):**
- **Модуль Stream:** Сквозной SNI для HTTPS трафика (ИИ-сервисы)
- **Модуль HTTP:** Обратный прокси с терминацией SSL (локальные сервисы)

**Слой DNS (Blocky/AdGuardHome):**
- Разрешает DNS-запросы для управляемых доменов
- Направляет домены на IP вашего прокси для перехвата трафика

## Лицензия

GPL-3.0 - см. файл [LICENSE](LICENSE) для подробностей
