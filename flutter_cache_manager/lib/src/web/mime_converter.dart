import 'dart:io';

///Converts the most common MIME types to the most expected file extension.
extension ContentTypeConverter on ContentType {
  String get fileExtension => mimeTypes[mimeType] ?? '.$subType';
}

final RegExp _safeFileExtension = RegExp(r'^\.[A-Za-z0-9]{1,10}$');

const _genericContentTypes = {
  'application/octet-stream',
  'application/x-octet-stream',
  'application/force-download',
  'application/download',
  'binary/octet-stream',
};

const _dynamicEndpointExtensions = {'.php', '.asp', '.aspx', '.cgi', '.jsp'};

/// Gets an extension from a specific content type or a safe URL path suffix.
///
/// Specific content types take precedence. Missing or generic content types
/// use a short alphanumeric URL suffix when available. Known server-side
/// endpoint suffixes are ignored. The result falls back to `.bin` for generic
/// types or an empty string when the content type is absent.
String fileExtensionFromContentTypeOrUri(String? contentTypeHeader, Uri? uri) {
  final contentType = contentTypeHeader == null
      ? null
      : ContentType.parse(contentTypeHeader);

  if (contentType != null &&
      !_genericContentTypes.contains(contentType.mimeType)) {
    return contentType.fileExtension;
  }

  final pathSegments = uri?.pathSegments;
  final fileName = pathSegments == null || pathSegments.isEmpty
      ? ''
      : pathSegments.last;
  final extensionIndex = fileName.lastIndexOf('.');
  if (extensionIndex > 0 && extensionIndex < fileName.length - 1) {
    final extension = fileName.substring(extensionIndex);
    if (_safeFileExtension.hasMatch(extension) &&
        !_dynamicEndpointExtensions.contains(extension.toLowerCase())) {
      return extension;
    }
  }

  return contentType == null ? '' : '.bin';
}

/// Source of MIME Types:
/// https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types
/// Updated on 20th of March in 2020 while being quarantined
const mimeTypes = {
  'application/vnd.android.package-archive': '.apk',
  'application/epub+zip': '.epub',
  'application/gzip': '.gz',
  'application/java-archive': '.jar',
  'application/json': '.json',
  'application/ld+json': '.jsonld',
  'application/msword': '.doc',
  'application/octet-stream': '.bin',
  'application/ogg': '.ogx',
  'application/pdf': '.pdf',
  'application/php': '.php',
  'application/rtf': '.rtf',
  'application/vnd.amazon.ebook': '.azw',
  'application/vnd.apple.installer+xml': '.mpkg',
  'application/vnd.mozilla.xul+xml': '.xul',
  'application/vnd.ms-excel': '.xls',
  'application/vnd.ms-fontobject': '.eot',
  'application/vnd.ms-powerpoint': '.ppt',
  'application/vnd.oasis.opendocument.presentation': '.odp',
  'application/vnd.oasis.opendocument.spreadsheet': '.ods',
  'application/vnd.oasis.opendocument.text': '.odt',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      '.pptx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      '.docx',
  'application/vnd.rar': '.rar',
  'application/vnd.visio': '.vsd',
  'application/x-7z-compressed': '.7z',
  'application/x-abiword': '.abw',
  'application/x-bzip': '.bz',
  'application/x-bzip2': '.bz2',
  'application/x-csh': '.csh',
  'application/x-freearc': '.arc',
  'application/x-sh': '.sh',
  'application/x-shockwave-flash': '.swf',
  'application/x-tar': '.tar',
  'application/xhtml+xml': '.xhtml',
  'application/xml': '.xml',
  'application/zip': '.zip',
  'audio/3gpp': '.3gp',
  'audio/3gpp2': '.3g2',
  'audio/aac': '.aac',
  'audio/x-aac': '.aac',
  'audio/midi': '.midi',
  'audio/x-midi': '.midi',
  'audio/x-m4a': '.m4a',
  'audio/m4a': '.m4a',
  'audio/mpeg': '.mp3',
  'audio/ogg': '.oga',
  'audio/opus': '.opus',
  'audio/wav': '.wav',
  'audio/x-wav': '.wav',
  'audio/webm': '.weba',
  'font/otf': '.otf',
  'font/ttf': '.ttf',
  'font/woff': '.woff',
  'font/woff2': '.woff2',
  'image/bmp': '.bmp',
  'image/gif': '.gif',
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/svg+xml': '.svg',
  'image/tiff': '.tiff',
  'image/vnd.microsoft.icon': '.ico',
  'image/webp': '.webp',
  'text/calendar': '.ics',
  'text/css': '.css',
  'text/csv': '.csv',
  'text/html': '.html',
  'text/javascript': '.js',
  'text/plain': '.txt',
  'text/xml': '.xml',
  'video/3gpp': '.3gp',
  'video/3gpp2': '.3g2',
  'video/mp2t': '.ts',
  'video/mpeg': '.mpeg',
  'video/ogg': '.ogv',
  'video/webm': '.webm',
  'video/x-msvideo': '.avi',
  'video/quicktime': '.mov',
};
