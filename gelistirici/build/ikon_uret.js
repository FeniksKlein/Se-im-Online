// Emoji → çizgi ikon tablosunu üretir (Lucide, ISC lisansı). Yalnız geliştirme ortamında çalıştırılır;
// çıktı www/tasarim_v5_ikon.js dosyasına yazılır ve depoya girer. Derleme (derle.js) bu betiğe ihtiyaç duymaz.
// Kullanım: NODE_PATH=<react-icons, react, react-dom olan klasör> node build/ikon_uret.js
const R = require('react'), S = require('react-dom/server'), L = require('react-icons/lu');
const fs = require('fs'), path = require('path');
const T = {
  '🏛': 'Landmark', '🏢': 'Building2', '🏦': 'Landmark|Banknote', '🤝': 'Handshake', '⚖': 'Scale', '💳': 'CreditCard', '🛡': 'Shield',
  '➕': 'Plus', '🏭': 'Factory', '🏗': 'Construction', '📊': 'ChartColumn|BarChart3|ChartBar', '🏡': 'House|Home', '🏠': 'House|Home', '🏪': 'Store',
  '📜': 'ScrollText', '🎙': 'Mic', '🎤': 'Mic', '📦': 'Package', '🗳': 'Vote', '📢': 'Megaphone', '📣': 'Megaphone', '📋': 'ClipboardList',
  '📍': 'MapPin', '📌': 'Pin', '🌾': 'Wheat', '📚': 'LibraryBig|Library', '🧾': 'ReceiptText|Receipt', '🔨': 'Gavel', '💸': 'Banknote',
  '🎟': 'Ticket', '💰': 'Coins', '📈': 'TrendingUp', '📉': 'TrendingDown', '📂': 'FolderOpen', '📁': 'Folder', '🗂': 'Folders|FolderOpen', '💼': 'BriefcaseBusiness|Briefcase',
  '🪧': 'Signpost', '⏳': 'Hourglass', '📒': 'NotebookText|Notebook', '🛍': 'ShoppingBag', '🛒': 'ShoppingCart', '🏬': 'Store', '🚌': 'Bus',
  '🏅': 'Medal', '🎖': 'Medal', '🏙': 'Building', '📰': 'Newspaper', '🗞': 'Newspaper', '✋': 'Hand', '🔒': 'Lock', '⚙': 'Settings', '🏷': 'Tag',
  '📝': 'NotebookPen|FilePen|FileText', '📥': 'Inbox', '📤': 'Send', '📱': 'Smartphone', '📺': 'Tv', '🌳': 'Trees|TreeDeciduous', '🏘': 'House|Home', '🔑': 'KeyRound|Key',
  '📄': 'FileText', '🔎': 'Search', '🔍': 'Search', '🚀': 'Rocket', '🌐': 'Globe', '⚠': 'TriangleAlert|AlertTriangle', '🌱': 'Sprout', '📡': 'RadioTower',
  '📨': 'Mail', '💬': 'MessageCircle', '⛔': 'Ban', '🚜': 'Tractor', '📖': 'BookOpen', '👥': 'Users', '👤': 'User', '💱': 'ArrowLeftRight', '🙋': 'Hand',
  '🚨': 'Siren', '🏆': 'Trophy', '🎯': 'Target', '🔗': 'Link', '💻': 'Laptop', '⚡': 'Zap', '🏥': 'Hospital', '🎓': 'GraduationCap', '🏨': 'Hotel',
  '🔧': 'Wrench', '⛽': 'Fuel', '🚗': 'Car', '♻': 'Recycle', '🪪': 'IdCard|Contact', '✍': 'PenLine', '📕': 'Book', '🌿': 'Leaf', '🏧': 'Banknote',
  '💵': 'Banknote', '🪙': 'Coins', '🔔': 'Bell', '🗺': 'Map', '🎨': 'Palette', '🔄': 'RefreshCw', '🚓': 'Siren', '🎁': 'Gift', '👁': 'Eye',
  '🏳': 'Flag', '📅': 'CalendarDays', '🗓': 'CalendarDays', '⏰': 'AlarmClock', '🕐': 'Clock', '✊': 'Megaphone', '🎪': 'Tent', '🌙': 'Moon',
  '🧑‍⚖': 'Scale', '👩‍⚖': 'Scale', '👨‍⚖': 'Scale', '🎬': 'Clapperboard', '📷': 'Camera', '🧱': 'BrickWall', '🛋': 'Sofa', '👕': 'Shirt', '☕': 'Coffee',
  '🍔': 'Utensils', '🥬': 'Salad', '🥛': 'Milk', '🥩': 'Beef', '🎉': 'PartyPopper', '✨': 'Sparkles', '🚪': 'DoorOpen', '🔥': 'Flame', '💡': 'Lightbulb',
  '📞': 'Phone', '🧭': 'Compass', '🏴': 'Flag', '🚩': 'Flag', '🗑': 'Trash2', '✏': 'Pencil', '📎': 'Paperclip', '🧮': 'Calculator', '🔐': 'LockKeyhole|Lock',
  '🏟': 'Landmark', '🚧': 'Construction', '🛠': 'Wrench', '🧑‍💼': 'User', '👔': 'BriefcaseBusiness|Briefcase', '🕊': 'Bird', '⭐': 'Star', '🌟': 'Star', '📑': 'Files|FileText',
};
const out = {}; const eksik = [];
for (const [e, adlar] of Object.entries(T)) {
  const ad = adlar.split('|').find(a => L['Lu' + a]);
  if (!ad) { eksik.push(e + ' ' + adlar); continue; }
  const svg = S.renderToStaticMarkup(R.createElement(L['Lu' + ad]));
  out[e] = svg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '').replace(/><\/(line|polygon|path|circle|rect|polyline|ellipse)>/g, '/>');
}
if (eksik.length) console.log('Bulunamayan:', eksik.join(', '));
const js = '/* Otomatik üretildi: build/ikon_uret.js — Lucide ikonları (ISC lisansı, lucide.dev). Elle düzenleme. */\n' +
  'window.SO_V5_IKON=' + JSON.stringify(out) + ';\n';
fs.writeFileSync(path.join(__dirname, '../www/tasarim_v5_ikon.js'), js);
console.log(Object.keys(out).length + ' ikon,', (js.length / 1024).toFixed(1) + ' KB');
