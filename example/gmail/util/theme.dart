import 'package:dart_tui/dart_tui.dart';

// Catppuccin Mocha-inspired palette.
const RgbColor cBase = RgbColor(30, 30, 46);
const RgbColor cMantle = RgbColor(24, 24, 37);
const RgbColor cCrust = RgbColor(17, 17, 27);
const RgbColor cSurface0 = RgbColor(49, 50, 68);
const RgbColor cSurface1 = RgbColor(69, 71, 90);
const RgbColor cSurface2 = RgbColor(88, 91, 112);
const RgbColor cOverlay0 = RgbColor(108, 112, 134);
const RgbColor cOverlay1 = RgbColor(127, 132, 156);
const RgbColor cSubtext0 = RgbColor(166, 173, 200);
const RgbColor cText = RgbColor(205, 214, 244);
const RgbColor cMauve = RgbColor(203, 166, 247);
const RgbColor cBlue = RgbColor(137, 180, 250);
const RgbColor cLavender = RgbColor(180, 190, 254);
const RgbColor cGreen = RgbColor(166, 227, 161);
const RgbColor cYellow = RgbColor(249, 226, 175);
const RgbColor cPeach = RgbColor(250, 179, 135);
const RgbColor cRed = RgbColor(243, 139, 168);
const RgbColor cPink = RgbColor(245, 194, 231);
const RgbColor cSapphire = RgbColor(116, 199, 236);

const Style sText = Style(foregroundRgb: cText);
const Style sDim = Style(foregroundRgb: cOverlay0, isDim: true);
const Style sMuted = Style(foregroundRgb: cSubtext0);
const Style sAccent = Style(foregroundRgb: cMauve, isBold: true);
const Style sHeader = Style(foregroundRgb: cLavender, isBold: true);
const Style sLink = Style(foregroundRgb: cBlue);
const Style sSuccess = Style(foregroundRgb: cGreen, isBold: true);
const Style sError = Style(foregroundRgb: cRed, isBold: true);
const Style sWarning = Style(foregroundRgb: cYellow, isBold: true);

const Style sBorder = Style(foregroundRgb: cSurface1);
const Style sBorderActive = Style(foregroundRgb: cMauve, isBold: true);

const Style sTabActive = Style(
  foregroundRgb: cBase,
  backgroundRgb: cMauve,
  isBold: true,
);
const Style sTabInactive = Style(
  foregroundRgb: cSubtext0,
);
const Style sTabUnread = Style(
  foregroundRgb: cPeach,
  isBold: true,
);

const Style sRowSelected = Style(
  foregroundRgb: cBase,
  backgroundRgb: cMauve,
  isBold: true,
);
const Style sRowSender = Style(foregroundRgb: cBlue, isBold: true);
const Style sRowSenderUnread = Style(foregroundRgb: cPeach, isBold: true);
const Style sRowSubject = Style(foregroundRgb: cText);
const Style sRowSubjectUnread = Style(foregroundRgb: cText, isBold: true);
const Style sRowDate = Style(foregroundRgb: cOverlay1);
const Style sRowLabel = Style(
  foregroundRgb: cBase,
  backgroundRgb: cSapphire,
);

const Style sStatusBar = Style(backgroundRgb: cSurface0, foregroundRgb: cText);
const Style sStatusKey = Style(
  foregroundRgb: cMauve,
  backgroundRgb: cSurface0,
  isBold: true,
);
const Style sStatusHint = Style(
  foregroundRgb: cOverlay1,
  backgroundRgb: cSurface0,
);

const Style sTitleBar = Style(
  foregroundRgb: cMauve,
  isBold: true,
);

// Unicode icons
const String iDot = '●';
const String iArrow = '▸';
const String iReload = '⟳';
const String iError = '✗';
const String iSearch = '⌕';
const String iMail = '✉';
const String iStar = '★';
