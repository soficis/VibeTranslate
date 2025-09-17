# TranslationFiesta Swift - Usage Guide

This guide provides detailed instructions for using the TranslationFiesta Swift application effectively.

## 🚀 Quick Start

### First Launch Setup

1. **Launch the Application**
   - Open TranslationFiesta Swift from Applications or Xcode
   - Grant necessary permissions when prompted

2. **Configure API Keys**
   - Click the **Settings** button (⚙️) in the toolbar
   - Navigate to **API Configuration**
   - Add your translation service API keys
   - Keys are automatically saved to macOS Keychain

3. **Set Preferences**
   - Choose default languages
   - Configure quality thresholds
   - Set budget limits (optional)

## 📝 Basic Translation

### Single Text Translation

1. **Select Source Language**
   - Use the dropdown on the left
   - Supports auto-detection for many languages

2. **Select Target Language**
   - Use the dropdown on the right
   - English ↔ Japanese focus with additional language support

3. **Enter Text**
   - Type directly in the source text area
   - Paste text using `⌘ + V`
   - Maximum length varies by API provider

4. **Translate**
   - Click **Translate** button
   - Use keyboard shortcut `⌘ + T`
   - Results appear in the target text area

5. **Back-Translation (Optional)**
   - Enable "Back-translate for validation"
   - System translates result back to source language
   - Compare for accuracy verification

### Translation Results

The translation interface displays:
- **Primary Translation**: Main translation result
- **Back-Translation**: Validation translation (if enabled)
- **Quality Score**: BLEU score assessment
- **Confidence Rating**: API-provided confidence level
- **Cost Information**: API usage cost for the translation

## 📁 Batch Processing

### Preparing Files

**Supported Formats:**
- Plain Text (`.txt`)
- JSON files (`.json`)
- XML documents (`.xml`)
- EPUB books (`.epub`)

**File Preparation Tips:**
- Ensure text encoding is UTF-8
- For JSON: Use structured format with text fields
- For XML: Ensure well-formed documents
- For EPUB: Backup originals before processing

### Batch Processing Workflow

1. **Access Batch Processor**
   - Click **Batch Process** in toolbar
   - Or use menu: File → Batch Process

2. **Add Files**
   - **Drag & Drop**: Drag files into the file list area
   - **Browse**: Click "Add Files" button
   - **Multiple Selection**: Hold `⌘` to select multiple files

3. **Configure Processing Options**
   - **Output Directory**: Choose where processed files are saved
   - **Export Format**: Select JSON, CSV, XML, or TXT
   - **Translation Settings**:
     - Enable/disable back-translation
     - Set quality thresholds
     - Choose API providers
   - **Processing Options**:
     - Concurrent file limit
     - Retry attempts for failures
     - Skip files with errors

4. **Start Processing**
   - Click **Start Batch Processing**
   - Monitor progress in real-time
   - Pause/resume as needed
   - Cancel processing if required

5. **Review Results**
   - Check processing summary
   - Review failed files (if any)
   - Access processed files in output directory

### Batch Processing Best Practices

- **Small Test First**: Process a few files before large batches
- **Monitor Resources**: Watch CPU and memory usage
- **Check API Limits**: Ensure sufficient API quota
- **Backup Originals**: Always keep original files safe
- **Review Quality**: Check sample translations before mass processing

## 🧠 Translation Memory

### Understanding Translation Memory

Translation Memory (TM) stores previously translated segments for reuse:
- **Exact Matches**: Identical source text reuses stored translation
- **Fuzzy Matches**: Similar text suggests stored translations
- **Learning**: System learns from all translations
- **Efficiency**: Reduces API calls and costs

### Using Translation Memory

1. **Access Translation Memory**
   - Click **Translation Memory** in toolbar
   - View current memory statistics

2. **Search Translation Memory**
   - Use search bar to find specific translations
   - Filter by source/target language
   - Sort by date, quality score, or frequency

3. **Memory Management**
   - **View Statistics**:
     - Total entries
     - Cache hit rate
     - Memory usage
     - Average quality scores
   - **Export Memory**: Save translation memory for backup
   - **Import Memory**: Load previously exported memory
   - **Clear Memory**: Remove all or selected entries

4. **Memory Settings**
   - **Cache Size**: Adjust maximum number of stored translations
   - **Similarity Threshold**: Set minimum similarity for fuzzy matches
   - **Auto-Accept**: Automatically use high-confidence matches
   - **Quality Filter**: Minimum quality score for stored translations

### Fuzzy Matching

Fuzzy matching finds similar translations:
- **Similarity Scoring**: 0-100% similarity calculation
- **Threshold Control**: Adjustable minimum similarity
- **Context Awareness**: Considers surrounding text
- **Intelligent Suggestions**: Highlights differences in similar text

## 💰 Cost Tracking

### Setting Up Budgets

1. **Access Cost Settings**
   - Open Settings → Cost Management
   - Configure budget parameters

2. **Budget Types**
   - **Daily Budget**: Maximum spending per day
   - **Monthly Budget**: Maximum spending per month
   - **Per-Project**: Individual project budgets
   - **API-Specific**: Different budgets per API provider

3. **Budget Alerts**
   - **Warning Levels**: 50%, 75%, 90% of budget
   - **Notification Types**: In-app alerts, system notifications
   - **Action on Limit**: Stop processing or warn only

### Monitoring Costs

1. **Real-Time Tracking**
   - Current session costs in status bar
   - Live budget remaining display
   - Cost per translation preview

2. **Cost Analytics**
   - **Dashboard**: Visual cost overview
   - **Reports**: Detailed spending analysis
   - **Trends**: Historical cost patterns
   - **Breakdown**: Costs by API, language pair, or project

3. **Cost Optimization**
   - **Translation Memory**: Reduces API calls
   - **Batch Discounts**: Some APIs offer batch pricing
   - **Quality Thresholds**: Avoid retranslations
   - **API Selection**: Choose cost-effective providers

## 📊 Quality Assessment

### BLEU Scoring

BLEU (Bilingual Evaluation Understudy) measures translation quality:
- **Score Range**: 0.0 (poor) to 1.0 (perfect)
- **Reference-Free**: Uses back-translation for evaluation
- **Automatic**: Calculated for all translations
- **Threshold Setting**: Filter translations below quality threshold

### Quality Indicators

- **BLEU Score**: Primary quality metric
- **Confidence Score**: API-provided confidence rating
- **Back-Translation Match**: Similarity to original text
- **Human Review Flag**: Mark translations needing review

### Improving Translation Quality

1. **Text Preparation**
   - Use clear, grammatically correct source text
   - Avoid ambiguous phrases
   - Provide context when possible

2. **API Selection**
   - Test different APIs for your content type
   - Some APIs excel at specific domains
   - Consider specialized models

3. **Quality Thresholds**
   - Set minimum acceptable BLEU scores
   - Automatically flag low-quality translations
   - Enable manual review for flagged content

## 📤 Export & Import

### Export Options

1. **Translation Export**
   - **Formats**: JSON, CSV, XML, Plain Text
   - **Content Options**:
     - Source and target text
     - Quality scores and metadata
     - Timestamp and API information
     - Cost data

2. **Export Workflow**
   - Select translations to export
   - Choose export format and options
   - Specify output location
   - Configure file naming

### Export Formats

**JSON Export**:
```json
{
  "translations": [
    {
      "source": "Hello world",
      "target": "こんにちは世界",
      "sourceLanguage": "en",
      "targetLanguage": "ja",
      "bleuScore": 0.85,
      "confidence": 0.92,
      "timestamp": "2024-01-15T10:30:00Z",
      "apiProvider": "GoogleTranslate",
      "cost": 0.0001
    }
  ],
  "summary": {
    "totalTranslations": 1,
    "averageQuality": 0.85,
    "totalCost": 0.0001
  }
}
```

**CSV Export**:
```csv
Source,Target,Source Lang,Target Lang,BLEU Score,Confidence,Timestamp,API,Cost
"Hello world","こんにちは世界","en","ja",0.85,0.92,"2024-01-15T10:30:00Z","GoogleTranslate",0.0001
```

### Import Features

1. **Translation Memory Import**
   - Load previously exported translation memories
   - Merge with existing memory
   - Validate imported data

2. **Settings Import**
   - API configurations
   - User preferences
   - Budget settings

## ⚙️ Settings & Preferences

### General Settings

- **Default Languages**: Set preferred source and target languages
- **Auto-Detection**: Enable automatic source language detection
- **Interface Theme**: Light/Dark/System theme selection
- **Font Size**: Adjust text display size

### Translation Settings

- **API Preferences**: Choose default translation providers
- **Quality Thresholds**: Minimum acceptable quality scores
- **Back-Translation**: Enable/disable by default
- **Batch Processing**: Default concurrent processing limits

### Privacy & Security

- **Data Retention**: How long to keep translation history
- **Network Logging**: Enable/disable request logging
- **Secure Deletion**: Overwrite deleted files
- **API Key Management**: View and manage stored keys

### Performance Settings

- **Translation Memory Cache**: Adjust cache size limits
- **Network Timeouts**: Configure request timeout values
- **Concurrent Requests**: Maximum simultaneous API calls
- **Background Processing**: Enable background tasks

## 🔧 Troubleshooting

### Common Issues

**Translation Fails**:
- Check API key configuration
- Verify network connectivity
- Confirm API quota availability
- Review text length limits

**Poor Translation Quality**:
- Try different API providers
- Improve source text clarity
- Enable back-translation validation
- Adjust quality thresholds

**Performance Issues**:
- Reduce concurrent processing
- Clear translation memory cache
- Close unnecessary applications
- Check available system memory

**File Processing Errors**:
- Verify file format support
- Check file encoding (use UTF-8)
- Ensure files aren't corrupted
- Review file size limits

### Debug Features

1. **Enable Debug Logging**
   - Settings → Advanced → Enable Debug Logs
   - View logs in Console.app or application logs

2. **Network Monitoring**
   - Monitor API requests and responses
   - Check request timing and errors
   - Review rate limiting issues

3. **Performance Profiling**
   - Monitor memory usage
   - Track processing speeds
   - Identify bottlenecks

### Getting Help

- **In-App Help**: Press `F1` or Help menu
- **Documentation**: Comprehensive guides in docs folder
- **Issue Reporting**: Use GitHub issues for bug reports
- **Community Support**: Join discussions and get help

## 📱 Keyboard Shortcuts

### Translation
- `⌘ + T`: Translate current text
- `⌘ + Shift + T`: Translate with back-translation
- `⌘ + R`: Repeat last translation
- `⌘ + L`: Swap source and target languages

### File Operations
- `⌘ + O`: Open file for translation
- `⌘ + S`: Save current translation
- `⌘ + Shift + S`: Save translation as...
- `⌘ + E`: Export translations

### Navigation
- `⌘ + 1`: Main translation view
- `⌘ + 2`: Batch processing view
- `⌘ + 3`: Translation memory view
- `⌘ + 4`: Cost tracking view
- `⌘ + ,`: Open preferences

### Application
- `⌘ + Q`: Quit application
- `⌘ + M`: Minimize window
- `⌘ + F`: Find in translation memory
- `F1`: Show help

---

This usage guide covers the essential features of TranslationFiesta Swift. For advanced features and development information, see the main README and other documentation files.