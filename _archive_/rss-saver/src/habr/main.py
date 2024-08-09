import feedparser
import requests
import logging
import time


class Habr:
  def __init__(self):
    logging.basicConfig(
      level=logging.DEBUG,
      format='%(asctime)s - %(levelname)s - %(message)s'
    )

    self.session = requests.Session()
    self.vxdb_addr = 'http://vxdb:8080'
    self.vxdb_bucket = 'habr.com'

  def get_db_keys(self):
    return self.session.get(f'{self.vxdb_addr}/{self.vxdb_bucket}').json()

  def set_db_key(self, key, value):
    save = self.session.put(f'{self.vxdb_addr}/{self.vxdb_bucket}/{key}', data=value)
    save.raise_for_status()

  def parse(self, url, params):
    habr = self.session.get(url, params=params)
    habr.raise_for_status()

    data = feedparser.parse(habr.text)
    for row in data.get('entries'):
      row_id = row.get('id')
      if not row_id:
        continue

      data_id = row_id.replace('https://habr.com/', '').replace('/', ':')
      if not data_id.endswith(':'): data_id += ':'
      data_id += 'html'

      if data_id not in self.get_db_keys():
        post = self.session.get(row.get('link'))
        self.set_db_key(data_id, post.text.encode('utf-8'))
        logging.info(f'Add: {data_id}')

  def run(self):
    rss = {
      'https://habr.com/ru/rss/all/all/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/all/top10/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/all/top25/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/all/top50/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/all/top100/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/best/daily/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/best/weekly/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/best/monthly/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/best/yearly/': {'fl': 'ru,en'},
      'https://habr.com/ru/rss/news/': {}
    }
    for url, params in rss.items():
      self.parse(url, params)

if __name__ == '__main__':
  while True:
    Habr().run()
    time.sleep(30 * 60)
