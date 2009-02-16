require 'fileutils'
require 'rexml/document'
require 'vendor/htree'

class DownloadHistory
  def initialize
    base_file = File.expand_path '~/.wallpaper_swipe'
    @output = File.new base_file, 'a'
    @already_downloaded = File.readlines(base_file).collect { |l| l.chomp }
  end
  
  def already_downloaded?(remote_path)
    @already_downloaded.include? remote_path
  end
  
  def log(remote_path)
    @output.puts remote_path
    @already_downloaded << remote_path
  end
end

def http_get_string(url)
  `curl -s #{url}`
end

def log(msg)
  puts msg if LOGGING
end

def process_image(remote_path)
  remote_path =~ %r|/([^/]+)$|
  basename = $1
  local_path = File.join(PICTURES_FOLDER, basename)
  if @@download_history.already_downloaded?(remote_path) &&
     (!File.exist?(local_path) || File.size(local_path) >= FILE_THRESHOLD)
    log "Already downloaded #{remote_path}, skipping"
  else
    tries = 0
    until (
      tries > 1 ||
      (File.exist?(local_path) && File.size(local_path) >= FILE_THRESHOLD)
    )
      `curl -s -o #{local_path} #{remote_path}`
      log "Saved #{remote_path} to #{local_path}"
      tries += 1
    end
    if File.exist?(local_path)
      @@download_history.log(remote_path)
      @@new_files = true
    end
  end
end

def process_page(url)
  page_doc = HTree(http_get_string(url)).to_rexml
  REXML::XPath.each(page_doc, "//img") do |img_elt|
    if img_elt.attributes['class'] == 'bpImage'
      process_image img_elt.attributes['src']
    end
  end
end

if __FILE__ == $0
  @@new_files = false
  FILE_THRESHOLD = 16 * 1024
  PICTURES_FOLDER = File.expand_path '~/Pictures/wallpaper_swipe'
  FileUtils.mkdir_p(PICTURES_FOLDER) unless File.exist?(PICTURES_FOLDER)
  APPROVED_FOLDER = File.join(PICTURES_FOLDER, 'approved')
  FileUtils.mkdir_p(APPROVED_FOLDER) unless File.exist?(APPROVED_FOLDER)
  @@download_history = DownloadHistory.new
  LOGGING = ENV['LOGGING']
  xml = http_get_string 'http://www.boston.com/bigpicture/index.xml'
  rexml_doc = REXML::Document.new xml
  rexml_doc.elements.each('rss/channel/item/link') do |link_elt|
    process_page link_elt.text.to_s
  end
  `open #{PICTURES_FOLDER}` if @@new_files
end