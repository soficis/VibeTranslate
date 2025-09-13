package epub

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"io/ioutil"
	"path/filepath"

	"golang.org/x/net/html/charset"
	"golang.org/x/text/transform"
)

// Chapter represents a chapter in an EPUB file.
type Chapter struct {
	Title string
	Path  string
}

// EPUBProcessor handles the processing of EPUB files.
type EPUBProcessor struct {
	zipReader *zip.ReadCloser
	opfPath   string
	ncxPath   string
	navMap    []NavPoint
}

// Structs for parsing EPUB XML files
type Container struct {
	RootFiles []RootFile `xml:"rootfiles>rootfile"`
}

type RootFile struct {
	FullPath string `xml:"full-path,attr"`
}

type Package struct {
	Manifest []ManifestItem `xml:"manifest>item"`
	Spine    Spine          `xml:"spine"`
}

type ManifestItem struct {
	ID        string `xml:"id,attr"`
	Href      string `xml:"href,attr"`
	MediaType string `xml:"media-type,attr"`
}

type Spine struct {
	Toc   string      `xml:"toc,attr"`
	Items []SpineItem `xml:"itemref"`
}

type SpineItem struct {
	IDRef string `xml:"idref,attr"`
}

type Ncx struct {
	NavMap []NavPoint `xml:"navMap>navPoint"`
}

type NavPoint struct {
	Text    string  `xml:"navLabel>text"`
	Content Content `xml:"content"`
}

type Content struct {
	Src string `xml:"src,attr"`
}

// NewEPUBProcessor creates a new EPUBProcessor and parses the EPUB structure.
func NewEPUBProcessor(filePath string) (*EPUBProcessor, error) {
	r, err := zip.OpenReader(filePath)
	if err != nil {
		return nil, err
	}

	p := &EPUBProcessor{zipReader: r}

	if err := p.parseContainer(); err != nil {
		return nil, err
	}

	if err := p.parseOpf(); err != nil {
		return nil, err
	}

	if err := p.parseNcx(); err != nil {
		return nil, err
	}

	return p, nil
}

// GetChapters returns the list of chapters.
func (p *EPUBProcessor) GetChapters() ([]Chapter, error) {
	var chapters []Chapter
	for _, point := range p.navMap {
		chapters = append(chapters, Chapter{
			Title: point.Text,
			Path:  point.Content.Src,
		})
	}
	return chapters, nil
}

// GetChapterContent returns the content of a chapter.
func (p *EPUBProcessor) GetChapterContent(chapterPath string) (string, error) {
	basePath := filepath.Dir(p.opfPath)
	fullPath := filepath.Join(basePath, chapterPath)

	rc, err := p.openFileInZip(fullPath)
	if err != nil {
		return "", err
	}
	defer rc.Close()

	// Read the raw content to detect encoding
	rawContent, err := ioutil.ReadAll(rc)
	if err != nil {
		return "", err
	}

	// Detect encoding and create a transforming reader
	encoding, _, _ := charset.DetermineEncoding(rawContent, "")
	reader := transform.NewReader(bytes.NewReader(rawContent), encoding.NewDecoder())

	// Read the transformed (UTF-8) content
	utf8Content, err := ioutil.ReadAll(reader)
	if err != nil {
		return "", err
	}

	return string(utf8Content), nil
}

// Close closes the underlying zip reader.
func (p *EPUBProcessor) Close() error {
	return p.zipReader.Close()
}

func (p *EPUBProcessor) parseContainer() error {
	rc, err := p.openFileInZip("META-INF/container.xml")
	if err != nil {
		return err
	}
	defer rc.Close()

	var container Container
	if err := xml.NewDecoder(rc).Decode(&container); err != nil {
		return err
	}

	p.opfPath = container.RootFiles[0].FullPath
	return nil
}

func (p *EPUBProcessor) parseOpf() error {
	rc, err := p.openFileInZip(p.opfPath)
	if err != nil {
		return err
	}
	defer rc.Close()

	var pkg Package
	if err := xml.NewDecoder(rc).Decode(&pkg); err != nil {
		return err
	}

	manifest := make(map[string]string)
	for _, item := range pkg.Manifest {
		manifest[item.ID] = item.Href
	}

	p.ncxPath = filepath.Join(filepath.Dir(p.opfPath), manifest[pkg.Spine.Toc])
	return nil
}

func (p *EPUBProcessor) parseNcx() error {
	rc, err := p.openFileInZip(p.ncxPath)
	if err != nil {
		return err
	}
	defer rc.Close()

	var ncx Ncx
	if err := xml.NewDecoder(rc).Decode(&ncx); err != nil {
		return err
	}

	p.navMap = ncx.NavMap
	return nil
}

func (p *EPUBProcessor) openFileInZip(name string) (io.ReadCloser, error) {
	for _, f := range p.zipReader.File {
		if f.Name == name {
			return f.Open()
		}
	}
	return nil, fmt.Errorf("file not found in archive: %s", name)
}
