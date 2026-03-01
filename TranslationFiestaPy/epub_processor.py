import ebooklib
from bs4 import BeautifulSoup
from ebooklib import epub


class EpubProcessor:
    def __init__(self, file_path):
        self.file_path = file_path
        self.book = epub.read_epub(file_path)

    def get_chapters(self):
        chapters = []
        for item in self.book.get_items_of_type(ebooklib.ITEM_DOCUMENT):
            chapters.append(item)
        return chapters

    def get_chapter_content(self, chapter):
        soup = BeautifulSoup(chapter.get_body_content(), 'html.parser')
        return soup.get_text()

    def get_book_title(self):
        return self.book.get_metadata('DC', 'title')[0][0]

if __name__ == '__main__':
    # Example usage:
    # processor = EpubProcessor('path/to/your/book.epub')
    # title = processor.get_book_title()
    # print(f"Title: {title}")
    # chapters = processor.get_chapters()
    # for i, chapter in enumerate(chapters):
    #     print(f"  Chapter {i + 1}: {chapter.get_name()}")
    #     # content = processor.get_chapter_content(chapter)
    #     # print(content[:200]) # Print first 200 characters
    pass
