"""Раздаёт релизную сборку build/web так, как это должен делать хостинг.

Любой путь, для которого нет файла (/cars/..., /appointments/...), получает
index.html — иначе прямой переход по ссылке вернёт 404 от сервера
(прямые ссылки на внутренние экраны).

Запуск:  python tool/serve.py [порт]      по умолчанию 5555
"""

import http.server
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'web')


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def send_head(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path):
            self.path = '/index.html'
        return super().send_head()


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5555
    print(f'http://localhost:{port}')
    http.server.ThreadingHTTPServer(('', port), SpaHandler).serve_forever()
