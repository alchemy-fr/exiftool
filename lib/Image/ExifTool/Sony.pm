#------------------------------------------------------------------------------
# File:         Sony.pm
#
# Description:  Sony EXIF Maker Notes tags
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#               2) http://homepage3.nifty.com/kamisaka/makernote/makernote_sony.htm (2006/08/06)
#               3) Thomas Bodenmann private communication
#               4) Philippe Devaux private communication (A700)
#               5) Marcus Holland-Moritz private communication (A700)
#               6) Andrey Tverdokhleb private communication
#               7) Rudiger Lange private communication (A700)
#               8) Igal Milchtaich private communication
#               9) Michael Reitinger private communication (DSC-TX7)
#               10) http://www.klingebiel.com/tempest/hd/pmp.html
#               11) Mike Battilana private communication
#               12) Jos Roost private communication (A580)
#               JD) Jens Duttke private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Sony;

use strict;
use vars qw($VERSION %sonyLensTypes);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::Minolta;

$VERSION = '1.61';

sub ProcessSRF($$$);
sub ProcessSR2($$$);
sub WriteSR2($$$);

# (%sonyLensTypes is filled in based on Minolta LensType's)

# ExposureProgram values (ref PH, mainly decoded from A200)
my %sonyExposureProgram = (
    0 => 'Auto', # (same as 'Program AE'?)
    1 => 'Manual',
    2 => 'Program AE',
    3 => 'Aperture-priority AE',
    4 => 'Shutter speed priority AE',
    8 => 'Program Shift A', #7
    9 => 'Program Shift S', #7
    19 => 'Night Portrait', # (A330)
    18 => 'Sunset', # (A330)
    17 => 'Sports', # (A330)
    21 => 'Macro', # (A330)
    20 => 'Landscape', # (A330)
    16 => 'Portrait', # (A330)
    35 => 'Auto No Flash', # (A330)
);

my %binaryDataAttrs = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
);

%Image::ExifTool::Sony::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        The following information has been decoded from the MakerNotes of Sony
        cameras.
    },
    0x0010 => [ #PH
        {
            Name => 'CameraInfo',
            # count: A33/A35/A55V/A450/A500/A550/A560/A580/NEX3/5/C3/VG10E=15360
            # (but this decoding is not valid for A450,A500,A550 or NEX models)
            Condition => '$$self{Model} =~ /^(SLT-A(33|35|55V)|DSLR-A(560|580))\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::CameraInfo' },
        },{
            Name => 'CameraInfoUnknown',
            # count: A200/A300/A350=5506, A230/A290/A330/A380/A390=6118, A700=368, A850/A900=5478
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::CameraInfoUnknown' },
        }
    ],
    # 0x0018 - starts with "GYRO" for sweep panorama images (ref 12)
    0x0020 => { #PH
        Name => 'FocusInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::FocusInfo',
            ByteOrder => 'BigEndian',
        },
    },
    0x0102 => { #5/JD
        Name => 'Quality',
        Writable => 'int32u',
        PrintConv => {
            0 => 'RAW',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra Fine',
            6 => 'RAW + JPEG',
            7 => 'Compressed RAW',
            8 => 'Compressed RAW + JPEG',
            0xffffffff => 'n/a', #PH (SLT-A57 panorama)
        },
    },
    0x0104 => { #5/JD
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Writable => 'rational64s',
    },
    0x0105 => { #5/JD
        Name => 'Teleconverter',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => \%Image::ExifTool::Minolta::minoltaTeleconverters,
    },
    0x0112 => { #JD
        Name => 'WhiteBalanceFineTune',
        Format => 'int32s',
        Writable => 'int32u',
    },
    0x0114 => [ #PH
        {
            Name => 'CameraSettings',
            # count: A200/A300/A350/A700=280, A850/A900=364
            Condition => '$count == 280 or $count == 364',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettings',
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'CameraSettings2',
            # count: A230/A290/A330/A380/A390=332
            Condition => '$count == 332',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettings2',
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'CameraSettings3',
            # count: A560/A580/A33/A35/A55/NEX3/5/C3/VG10E=1536, A450/A500/A550=2048
            Condition => '$count == 1536 || $count == 2048',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettings3',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'CameraSettingsUnknown',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettingsUnknown',
                ByteOrder => 'BigEndian',
            },
        },
    ],
    0x0115 => { #JD
        Name => 'WhiteBalance',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Auto',
            0x01 => 'Color Temperature/Color Filter',
            0x10 => 'Daylight',
            0x20 => 'Cloudy',
            0x30 => 'Shade',
            0x40 => 'Tungsten',
            0x50 => 'Flash',
            0x60 => 'Fluorescent',
            0x70 => 'Custom',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    # the next 3 tags have a different meaning for some models (with format int32u)
    0x1000 => { #9 (F88, multi burst mode only)
        Name => 'MultiBurstMode',
        Condition => '$format eq "undef"',
        Notes => 'MultiBurst tags valid only for models with this feature, like the F88',
        Writable => 'undef',
        Format => 'int8u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x1001 => { #9 (F88, multi burst mode only)
        Name => 'MultiBurstImageWidth',
        Condition => '$format eq "int16u"',
        Writable => 'int16u',
    },
    0x1002 => { #9 (F88, multi burst mode only)
        Name => 'MultiBurstImageHeight',
        Condition => '$format eq "int16u"',
        Writable => 'int16u',
    },
    0x1003 => { #9 (TX7, panorama mode only)
        Name => 'Panorama',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Panorama' },
    },
    # 0x2000 - undef[1]
    0x2001 => { #PH (JPEG images from all DSLR's except the A100)
        Name => 'PreviewImage',
        Writable => 'undef',
        DataTag => 'PreviewImage',
        # Note: the preview data starts with a 32-byte proprietary Sony header
        WriteCheck => 'return $val=~/^(none|.{32}\xff\xd8\xff)/s ? undef : "Not a valid image"',
        RawConv => q{
            return \$val if $val =~ /^Binary/;
            $val = substr($val,0x20) if length($val) > 0x20;
            return \$val if $val =~ s/^.(\xd8\xff\xdb)/\xff$1/s;
            $$self{PreviewError} = 1 unless $val eq 'none';
            return undef;
        },
        # must construct 0x20-byte header which contains length, width and height
        ValueConvInv => q{
            return 'none' unless $val;
            my $e = new Image::ExifTool;
            my $info = $e->ImageInfo(\$val,'ImageWidth','ImageHeight');
            return undef unless $$info{ImageWidth} and $$info{ImageHeight};
            my $size = Set32u($$info{ImageWidth}) . Set32u($$info{ImageHeight});
            return Set32u(length $val) . $size . ("\0" x 8) . $size . ("\0" x 4) . $val;
        },
    },
    # 0x2002 - int32u: probably Sharpness (PH guess)
    # 0x2003 - string[256]
    0x2004 => { #PH (NEX-5)
        Name => 'Contrast',
        Writable => 'int32s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x2005 => { #PH (NEX-5)
        Name => 'Saturation',
        Writable => 'int32s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x2006 => { #PH
        Name => 'Sharpness',
        Writable => 'int32s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x2007 => { #PH
        Name => 'Brightness',
        Writable => 'int32s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x2008 => { #PH
        Name => 'LongExposureNoiseReduction',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'On (unused)',
            0x10001 => 'On (dark subtracted)', # (NEX-C3)
            0xffff0000 => 'Off (65535)',
            0xffff0001 => 'On (65535)',
            0xffffffff => 'n/a',
        },
    },
    0x2009 => { #PH
        Name => 'HighISONoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Normal',
            3 => 'High',
            256 => 'Auto',
            65535 => 'n/a',
        },
    },
    0x200a => { #PH (A550)
        Name => 'HDR',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConvColumns => 3,
        PrintConv => {
            0x0 => 'Off',
            # not sure what the high word means; have seen 0x0, 0x1, 0x2 and 0x3
            # - values with high word zero seen in 1st (nominal exposure) image of an A580 HDR pair
            0x01 => 'Auto (0)',
            0x10 => '1.0 EV (0)',
            0x11 => '1.5 EV (0)',
            0x12 => '2.0 EV (0)',
            0x13 => '2.5 EV (0)',
            0x14 => '3.0 EV (0)',
            0x15 => '3.5 EV (0)',
            0x16 => '4.0 EV (0)',
            0x17 => '4.5 EV (0)',
            0x18 => '5.0 EV (0)',
            0x19 => '5.5 EV (0)',
            0x1a => '6.0 EV (0)',
            0x10001 => 'Auto',
            0x10010 => '1.0 EV', # (NEX-5)
            0x10011 => '1.5 EV',
            0x10012 => '2.0 EV',
            0x10013 => '2.5 EV',
            0x10014 => '3.0 EV',
            0x10015 => '3.5 EV',
            0x10016 => '4.0 EV',
            0x10017 => '4.5 EV',
            0x10018 => '5.0 EV',
            0x10019 => '5.5 EV',
            0x1001a => '6.0 EV', # (SLT-A55V)
            0x20001 => 'Auto (2)',
            0x20010 => '1.0 EV (2)',
            0x20011 => '1.5 EV (2)',
            0x20012 => '2.0 EV (2)',
            0x20013 => '2.5 EV (2)',
            0x20014 => '3.0 EV (2)',
            0x20015 => '3.5 EV (2)',
            0x20016 => '4.0 EV (2)',
            0x20017 => '4.5 EV (2)',
            0x20018 => '5.0 EV (2)',
            0x20019 => '5.5 EV (2)',
            0x2001a => '6.0 EV (2)',
            0x30001 => 'Auto (3)',
            0x30010 => '1.0 EV (3)',
            0x30011 => '1.5 EV (3)',
            0x30012 => '2.0 EV (3)',
            0x30013 => '2.5 EV (3)',
            0x30014 => '3.0 EV (3)',
            0x30015 => '3.5 EV (3)',
            0x30016 => '4.0 EV (3)',
            0x30017 => '4.5 EV (3)',
            0x30018 => '5.0 EV (3)',
            0x30019 => '5.5 EV (3)',
            0x3001a => '6.0 EV (3)',
        },
    },
    0x200b => { #PH
        Name => 'MultiFrameNoiseReduction',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            255 => 'n/a',
        },
    },
    # 0x200c - int32u[3]: '0 0 0'
    # 0x200d - rational64u: 10/10
    # 0x200e - int16u: 0
    # 0x200f - int32u: 0
    0x2011 => { #PH (A77, NEX-5N)
        Name => 'VignettingCorrection',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            2 => 'Auto',
        },
    },
    0x2012 => { #PH (A77, NEX-5N)
        Name => 'LateralChromaticAberration',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            2 => 'Auto',
        },
    },
    0x2013 => { #PH (A77, NEX-5N)
        Name => 'DistortionCorrection',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            2 => 'Auto',
        },
    },
    # 0x2014 - int32s[2]: '0 0', '0 -1', '0 -2'
    # 0x2015 - int16u: 65535
    0x3000 => {
        Name => 'ShotInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::ShotInfo',
        },
    },
    # 0x3000: data block that includes DateTimeOriginal string
    0xb000 => { #8
        Name => 'FileFormat',
        Writable => 'int8u',
        Count => 4,
        # dynamically set the file type to SR2 because we could have assumed ARW up till now
        RawConv => q{
            $self->OverrideFileType($$self{TIFF_TYPE} = 'SR2') if $val eq '1 0 0 0';
            return $val;
        },
        PrintConvColumns => 2,
        PrintConv => {
            '0 0 0 2' => 'JPEG',
            '1 0 0 0' => 'SR2',
            '2 0 0 0' => 'ARW 1.0',
            '3 0 0 0' => 'ARW 2.0',
            '3 1 0 0' => 'ARW 2.1',
            '3 2 0 0' => 'ARW 2.2', #PH (NEX-5)
            '3 3 0 0' => 'ARW 2.3', #PH (SLT-A65,SLT-A77)
            # what about cRAW images?
        },
    },
    0xb001 => { # ref http://forums.dpreview.com/forums/read.asp?forum=1037&message=33609644
        # (ARW and SR2 images only until the SLT-A65V started writing them to JPEG too)
        Name => 'SonyModelID',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            2 => 'DSC-R1',
            256 => 'DSLR-A100',
            257 => 'DSLR-A900',
            258 => 'DSLR-A700',
            259 => 'DSLR-A200',
            260 => 'DSLR-A350',
            261 => 'DSLR-A300',
            262 => 'DSLR-A900 (APS-C mode)', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3994.0.html
            263 => 'DSLR-A380/A390', #PH (A390)
            264 => 'DSLR-A330',
            265 => 'DSLR-A230',
            266 => 'DSLR-A290', #PH
            269 => 'DSLR-A850',
            270 => 'DSLR-A850 (APS-C mode)', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3994.0.html
            273 => 'DSLR-A550',
            274 => 'DSLR-A500', #PH
            275 => 'DSLR-A450', # (http://dev.exiv2.org/issues/show/0000611)
            278 => 'NEX-5', #PH
            279 => 'NEX-3', #PH
            280 => 'SLT-A33', #PH
            281 => 'SLT-A55V', #PH
            282 => 'DSLR-A560', #PH
            283 => 'DSLR-A580', # (http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2881.0.html)
            284 => 'NEX-C3', #PH
            285 => 'SLT-A35', #12
            286 => 'SLT-A65V', #PH
            287 => 'SLT-A77V', #PH
            288 => 'NEX-5N', #PH
            289 => 'NEX-7', #PH
            290 => 'NEX-VG20E', #12
            292 => 'SLT-A57', #12
        },
    },
    0xb020 => { #2
        Name => 'ColorReproduction',
        # observed values: None, Standard, Vivid, Real, AdobeRGB - PH
        Writable => 'string',
    },
    0xb021 => { #2
        Name => 'ColorTemperature',
        Writable => 'int32u',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/Auto/i ? 0 : $val',
    },
    0xb022 => { #7
        Name => 'ColorCompensationFilter',
        Format => 'int32s',
        Writable => 'int32u', # (written incorrectly as unsigned by Sony)
        Notes => 'negative is green, positive is magenta',
    },
    0xb023 => { #PH (A100) - (set by mode dial)
        Name => 'SceneMode',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => \%Image::ExifTool::Minolta::minoltaSceneMode,
    },
    0xb024 => { #PH (A100)
        Name => 'ZoneMatching',
        Writable => 'int32u',
        PrintConv => {
            0 => 'ISO Setting Used',
            1 => 'High Key',
            2 => 'Low Key',
        },
    },
    0xb025 => { #PH (A100)
        Name => 'DynamicRangeOptimizer',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Auto', # (A550)
            8 => 'Advanced Lv1', #JD
            9 => 'Advanced Lv2', #JD
            10 => 'Advanced Lv3', #JD
            11 => 'Advanced Lv4', #JD
            12 => 'Advanced Lv5', #JD
            16 => 'Lv1', # (NEX-5)
            17 => 'Lv2',
            18 => 'Lv3',
            19 => 'Lv4',
            20 => 'Lv5',
        },
    },
    0xb026 => { #PH (A100)
        Name => 'ImageStabilization',
        Writable => 'int32u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0xb027 => { #2
        Name => 'LensType',
        Writable => 'int32u',
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%sonyLensTypes,
    },
    0xb028 => { #2
        # (used by the DSLR-A100)
        Name => 'MinoltaMakerNote',
        # must check for zero since apparently a value of zero indicates the IFD doesn't exist
        # (dumb Sony -- they shouldn't write this tag if the IFD is missing!)
        Condition => '$$valPt ne "\0\0\0\0"',
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::Main',
            Start => '$val',
        },
    },
    0xb029 => { #2 (set by creative style menu)
        Name => 'ColorMode',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => \%Image::ExifTool::Minolta::sonyColorMode,
    },
    0xb02a => {
        Name => 'LensSpec',
        Format => 'undef',
        Writable => 'int8u',
        Count => 8,
        Notes => q{
            like LensInfo, but also specifies lens features: DT, E, ZA, G, SSM, SAM,
            OSS, STF, Reflex, Macro and Fisheye
        },
        # unpack in format compatible with LensInfo, with extra flags word at end
        ValueConv => sub {
            my $val = shift;
            return \$val unless length($val) == 8;
            my @a = unpack("H2H4H4H2H2H2",$val);
            $a[1] += 0;  $a[2] += 0;    # remove leading zeros from focal lengths
            $a[3] /= 10; $a[4] /= 10;   # divide f-numbers by 10
            return join ' ', @a;
        },
        ValueConvInv => sub {
            my $val = shift;
            my @a=split(" ", $val);
            return $val unless @a == 6;
            $a[3] *= 10; $a[4] *= 10;   # f-numbers are multiplied by 10
            $_ = hex foreach @a;        # convert from hex
            return pack 'CnnCCC', @a;
        },
        PrintConv => 'Image::ExifTool::Sony::PrintLensSpec($val)',
        PrintConvInv => 'Image::ExifTool::Sony::PrintInvLensSpec($val)',
    },
    0xb02b => { #PH (A550 JPEG and A200, A230, A300, A350, A380, A700 and A900 ARW)
        Name => 'FullImageSize',
        Writable => 'int32u',
        Count => 2,
        # values stored height first, so swap to get "width height"
        ValueConv => 'join(" ", reverse split(" ", $val))',
        ValueConvInv => 'join(" ", reverse split(" ", $val))',
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0xb02c => { #PH (A550 JPEG and A200, A230, A300, A350, A380, A700 and A900 ARW)
        Name => 'PreviewImageSize',
        Writable => 'int32u',
        Count => 2,
        ValueConv => 'join(" ", reverse split(" ", $val))',
        ValueConvInv => 'join(" ", reverse split(" ", $val))',
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0xb040 => { #2
        Name => 'Macro',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Close Focus', #9
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb041 => { #2
        Name => 'ExposureMode',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto',
            1 => 'Portrait', #PH (HX1)
            2 => 'Beach', #9
            4 => 'Snow', #9
            5 => 'Landscape',
            6 => 'Program',
            7 => 'Aperture Priority',
            8 => 'Shutter Priority',
            9 => 'Night Scene / Twilight',#2/9
            10 => 'Hi-Speed Shutter', #9
            11 => 'Twilight Portrait', #9
            12 => 'Soft Snap', #9
            13 => 'Fireworks', #9
            14 => 'Smile Shutter', #9 (T200)
            15 => 'Manual',
            18 => 'High Sensitivity', #9
            20 => 'Advanced Sports Shooting', #9
            29 => 'Underwater', #9
            33 => 'Gourmet', #9
            34 => 'Panorama', #PH (HX1)
            35 => 'Handheld Night Shot', #PH (HX1/TX1, also called "Hand-held Twilight")
            36 => 'Anti Motion Blur', #PH (TX1)
            37 => 'Pet', #9
            38 => 'Backlight Correction HDR', #9
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb042 => { #9
        Name => 'FocusMode',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            1 => 'AF-S', # (called Single-AF by Sony)
            2 => 'AF-C', # (called Monitor-AF by Sony)
            4 => 'Permanent-AF', # (TX7)
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb043 => { #9
        Name => 'AFMode',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Default', # (takes this value after camera reset, but can't be set back once changed)
            1 => 'Multi AF',
            2 => 'Center AF',
            3 => 'Spot AF',
            4 => 'Flexible Spot AF', # (T200)
            6 => 'Touch AF',
            14 => 'Manual Focus', # (T200)
            15 => 'Face Detected', # (not set when in face detect mode and no faces detected)
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb044 => { #9
        Name => 'AFIlluminator',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            65535 => 'n/a', #PH (A100)
        },
    },
    # 0xb045 - int16u: 0
    # 0xb046 - int16u: 0
    0xb047 => { #2
        Name => 'Quality',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Normal',
            1 => 'Fine',
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb048 => { #9
        Name => 'FlashLevel',
        Writable => 'int16s',
        RawConv => '($val == -1 and $$self{Model} =~ /DSLR-A100\b/) ? undef : $val',
        PrintConv => {
            -32768 => 'Low',
            -3 => '-3/3',
            -2 => '-2/3',
            -1 => '-1/3', # (for the A100, -1 is effectively 'n/a' - PH)
            0 => 'Normal',
            1 => '+1/3',
            2 => '+2/3',
            3 => '+3/3',
            # 128 - have seen this
            32767 => 'High',
        },
    },
    0xb049 => { #9
        Name => 'ReleaseMode',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Normal',
            2 => 'Burst',
            5 => 'Exposure Bracketing',
            6 => 'White Balance Bracketing', # (HX5)
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb04a => { #9
        Name => 'SequenceNumber',
        Notes => 'shot number in continuous burst',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Single',
            65535 => 'n/a', #PH (A100)
            OTHER => sub { shift }, # pass all other numbers straight through
        },
    },
    0xb04b => { #2/PH
        Name => 'Anti-Blur',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On (Continuous)', #PH (NC)
            2 => 'On (Shooting)', #PH (NC)
            65535 => 'n/a',
        },
    },
    # 0xb04c - rational64u: 10/10
    # 0xb04d - int16u: 0
    # 0xb050 - int16u: 65535
    # 0xb051/0xb053 - int16u: 0
    0xb04e => { #2
        Name => 'LongExposureNoiseReduction',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            # 2 - seen this (TX10, TX100, WX9, WX10, etc
            # 4 - seen this (CX360E, CX700E)
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb04f => { #PH (TX1)
        Name => 'DynamicRangeOptimizer',
        Writable => 'int16u',
        Priority => 0, # (unreliable for the A77)
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Plus',
            # 8 for HDR models - what does this mean?
        },
    },
    0xb052 => { #PH (TX1)
        Name => 'IntelligentAuto',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Advanced', #9
        },
    },
    0xb054 => { #PH (TX1)
        Name => 'WhiteBalance',
        Writable => 'int16u',
        Priority => 0, # (until more values are filled in)
        PrintConv => {
            0 => 'Auto',
            4 => 'Manual',
            5 => 'Daylight',
            6 => 'Cloudy', #9
            7 => 'White Flourescent', #9      (Sony "Fluorescent 1 (White)")
            8 => 'Cool White Flourescent', #9 (Sony "Fluorescent 2 (Natural White)")
            9 => 'Day White Flourescent', #9  (Sony "Fluorescent 3 (Day White)")
            14 => 'Incandescent',
            15 => 'Flash', #9
            17 => 'Underwater 1 (Blue Water)', #9
            18 => 'Underwater 2 (Green Water)', #9
        },
    },
);

# "SEMC MS" maker notes
%Image::ExifTool::Sony::Ericsson = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Maker notes found in images from some Sony Ericsson phones.',
    0x2000 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x201 => {
        Name => 'PreviewImageStart',
        IsOffset => 1,
        MakerPreview => 1, # force preview inside maker notes
        OffsetPair => 0x202,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
        Notes => 'a small 320x200 preview image',
    },
    0x202 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x201,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
);

# Camera information for the A55 (ref PH)
# (also valid for A33, A35, A560, A580 - ref 12)
%Image::ExifTool::Sony::CameraInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Camera information stored by the A33, A35, A55, A560 and A580.',
    0x1c => {
        Name => 'AFPointSelected',  # (v8.88: renamed from LocalAFAreaPointSelected)
        Notes => 'not valid when AFAreaMode is "Flexible"', #12
        # (all of these cameras have an 15-point three-cross AF system, ref 12)
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto', # (seen in Wide mode)
            1 => 'Center',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Right',
            5 => 'Lower-right',
            6 => 'Bottom',
            7 => 'Lower-left',
            8 => 'Left',
            9 => 'Upper-left',
            10 => 'Far Right',
            11 => 'Far Left',
            12 => 'Upper-middle',
            13 => 'Near Right',
            14 => 'Lower-middle',
            15 => 'Near Left',
        },
    },
    0x1d => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
        },
    },
    0x20 => { #12
        Name => 'AFPointUsed',  # (v8.88: renamed from LocalAFAreaPointUsed)
        Notes => 'the AF sensor used for focusing. Not valid when AFAreaMode is "Flexible"',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Upper-left',
            1 => 'Left',
            2 => 'Lower-left',
            3 => 'Far Left',
            4 => 'Top (horizontal)',
            5 => 'Near Right',
            6 => 'Center (horizontal)',
            7 => 'Near Left',
            8 => 'Bottom (horizontal)',
            9 => 'Top (vertical)',
            10 => 'Center (vertical)',
            11 => 'Bottom (vertical)',
            12 => 'Far Right',
            13 => 'Upper-right',
            14 => 'Right',
            15 => 'Lower-right',
            16 => 'Upper-middle',
            17 => 'Lower-middle',
        },
    },
);

# unknown camera information
%Image::ExifTool::Sony::CameraInfoUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# focus information ("WBInfo" for the A100 in Minolta.pm) (ref PH)
%Image::ExifTool::Sony::FocusInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x09bb => {
        Condition => '$$self{Model} eq "DSLR-A850"',
        Notes => 'A850 only',
        Name => 'FocusPosition',  # 128 = infinity -- see Composite:FocusDistance below
    },
);

# Camera settings (ref PH) (decoded mainly from A200)
%Image::ExifTool::Sony::CameraSettings = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    NOTES => 'Camera settings for the A200, A300, A350, A700, A850 and A900.',
    0x04 => { #7 (A700, not confirmed for other models)
        Name => 'DriveMode',
        PrintConv => {
            1 => 'Single Frame',
            2 => 'Continuous High',
            4 => 'Self-timer 10 sec',
            5 => 'Self-timer 2 sec',
            7 => 'Continuous Bracketing',
            12 => 'Continuous Low',
            18 => 'White Balance Bracketing Low',
            19 => 'D-Range Optimizer Bracketing Low',
        },
    },
    0x06 => { #7 (A700, not valid for other models?)
        Name => 'WhiteBalanceFineTune',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Format => 'int16s',
        Notes => 'A700 only',
    },
    0x10 => { #7 (A700)
        Name => 'FocusMode',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
        },
    },
    0x11 => { #JD (A700)
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Wide',
            1 => 'Local',
            2 => 'Spot',
        },
    },
    0x12 => { #7 (A700)
        Name => 'AFPointSelected',
        Format => 'int16u',
        # A200, A300, A350: 9-point centre-cross (ref 12)
        # A700: 11-point centre-dual-cross (ref 12)
        # A850, A900: 9-point centre-dual-cross with 10 assist-points (ref 12)
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Center',
            2 => 'Top',
            3 => 'Top-Right',
            4 => 'Right',
            5 => 'Bottom-Right',
            6 => 'Bottom',
            7 => 'Bottom-Left',
            8 => 'Left',
            9 => 'Top-Left',
            10 => 'Far Right', # (presumbly A700 only)
            11 => 'Far Left', # (presumbly A700 only)
        },
    },
    0x15 => { #7
        Name => 'MeteringMode',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted Average',
            4 => 'Spot',
        },
    },
    0x16 => {
        Name => 'ISOSetting',
        # 0 indicates 'Auto' (I think)
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },
    0x18 => { #7
        Name => 'DynamicRangeOptimizerMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Advanced Level',
        },
    },
    0x19 => { #7
        Name => 'DynamicRangeOptimizerLevel',
    },
    0x1a => { # style actually used (combination of mode dial + creative style menu)
        Name => 'CreativeStyle',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait',
            4 => 'Landscape',
            5 => 'Sunset',
            6 => 'Night View/Portrait',
            8 => 'B&W',
            9 => 'Adobe RGB', # A900
            11 => 'Neutral',
            12 => 'Clear', #7
            13 => 'Deep', #7
            14 => 'Light', #7
            15 => 'Autumn', #7
            16 => 'Sepia', #7
        },
    },
    0x1c => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1d => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1e => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1f => { #7
        Name => 'ZoneMatchingValue',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x22 => { #7
        Name => 'Brightness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x23 => {
        Name => 'FlashMode',
        PrintConv => {
            0 => 'ADI',
            1 => 'TTL',
        },
    },
    0x28 => { #7
        Name => 'PrioritySetupShutterRelease',
        PrintConv => {
            0 => 'AF',
            1 => 'Release',
        },
    },
    0x29 => { #7
        Name => 'AFIlluminator',
        PrintConv => {
            0 => 'Auto',
            1 => 'Off',
        },
    },
    0x2a => { #7
        Name => 'AFWithShutter',
        PrintConv => { 0 => 'On', 1 => 'Off' },
    },
    0x2b => { #7
        Name => 'LongExposureNoiseReduction',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x2c => { #7
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
            3 => 'Off',
        },
    },
    0x2d => [
        { #7
            Name => 'ImageStyle',
            Condition => '$$self{Model} eq "DSLR-A700"',
            Notes => 'A700',
            PrintConvColumns => 2,
            PrintConv => {
                1 => 'Standard',
                2 => 'Vivid',
                3 => 'Portrait', #PH
                4 => 'Landscape', #PH
                5 => 'Sunset', #PH
                7 => 'Night View/Portrait', #PH (A200/A350 when CreativeStyle was 6!)
                8 => 'B&W', #PH (guess)
                9 => 'Adobe RGB',
                11 => 'Neutral',
                129 => 'StyleBox1',
                130 => 'StyleBox2',
                131 => 'StyleBox3',
            },
        },{
            Name => 'ImageStyle',
            Notes => 'other models',
            PrintConvColumns => 2,
            PrintConv => {
                1 => 'Standard',
                2 => 'Vivid',
                3 => 'Portrait', #PH
                4 => 'Landscape', #PH
                5 => 'Sunset', #PH
                7 => 'Night View/Portrait', #PH (A200/A350 when CreativeStyle was 6!)
                8 => 'B&W', #PH (guess)
                9 => 'Adobe RGB',
                11 => 'Neutral',
                # the following decoded for the A900 ("custom" is a guess) - PH
                129 => 'Standard (custom)', #PH
                130 => 'Vivid (custom)', #PH
                131 => 'Neutral (custom)', #PH
                132 => 'Portrait (custom)', #PH
                133 => 'Landscape (custom)', #PH
                134 => 'B&W (custom)', #PH
            },
        },
    ],
    0x3c => {
        Name => 'ExposureProgram',
        Priority => 0,
        PrintConv => \%sonyExposureProgram,
    },
    0x3d => {
        Name => 'ImageStabilization',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x3f => { # (verified for A330/A380)
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW', #(NC)
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => {
        Name => 'SonyImageSize',
        PrintConv => {
            1 => 'Large',
            2 => 'Medium',
            3 => 'Small',
        },
    },
    0x55 => { #7
        Name => 'AspectRatio',
        PrintConv => {
            1 => '3:2',
            2 => '16:9',
        },
    },
    0x56 => { #PH/7
        Name => 'Quality',
        PrintConv => {
            0 => 'RAW',
            2 => 'CRAW',
            34 => 'RAW + JPEG',
            35 => 'CRAW + JPEG',
            16 => 'Extra Fine',
            32 => 'Fine',
            48 => 'Standard',
        },
    },
    0x58 => { #7
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            33 => '1/3 EV',
            50 => '1/2 EV',
        },
    },
    0x9b => { #12
        Name => 'ImageNumber',
        ValueConv => '$val & 0x3fff', #PH (not sure what the upper 2 bits are for)
        ValueConvInv => '$val',
        PrintConv => 'sprintf("%.4d",$val)',
        PrintConvInv => '$val',
    },
);

# Camera settings (ref PH) (A230, A290, A330, A380 and A390)
%Image::ExifTool::Sony::CameraSettings2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    NOTES => 'Camera settings for the A230, A290, A330, A380 and A390.',
    # 0x05 - probably WhiteBalanceFineTune
    0x0f => { #12/PH (educated guess)
        Name => 'FocusMode',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
            # seen 5 for A380
        },
    },
    0x10 => { #12/PH (educated guess)
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Wide',
            1 => 'Local',
            2 => 'Spot',
        },
    },
    0x11 => { #12/PH (educated guess)
        Name => 'AFPointSelected',
        Format => 'int16u',
        # (all of these cameras have a 9-point centre-cross AF system, ref 12)
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Center',
            2 => 'Top',
            3 => 'Top-Right',
            4 => 'Right',
            5 => 'Bottom-Right',
            6 => 'Bottom',
            7 => 'Bottom-Left',
            8 => 'Left',
            9 => 'Top-Left',
        },
    },
    0x13 => {
        Name => 'MeteringMode',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted Average',
            4 => 'Spot',
        },
    },
    0x14 => { # A330/A380
        Name => 'ISOSetting',
        # 0 indicates 'Auto' (?)
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },
    0x16 => {
        Name => 'DynamicRangeOptimizerMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Advanced Level',
        },
    },
    0x17 => 'DynamicRangeOptimizerLevel',
    0x18 => { # A380
        Name => 'CreativeStyle',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait',
            4 => 'Landscape',
            5 => 'Sunset',
            6 => 'Night View/Portrait',
            8 => 'B&W',
            # (these models don't have Neutral - PH)
        },
    },
    0x19 => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1a => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1b => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    # 0x1e - could be Brightness?
    0x1f => { #PH (educated guess)
        Name => 'FlashMode',
        PrintConv => {
            0 => 'ADI',
            1 => 'TTL',
        },
    },
    0x25 => { #PH
        Name => 'LongExposureNoiseReduction',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x26 => { #PH
        Name => 'HighISONoiseReduction',
        # (Note: the order is different from that in CameraSettings)
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Normal',
            3 => 'High',
        },
    },
    0x27 => { #PH
        Name => 'ImageStyle',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait', #PH
            4 => 'Landscape', #PH
            5 => 'Sunset', #PH
            7 => 'Night View/Portrait', #PH (A200 when CreativeStyle was 6!)
            8 => 'B&W', #PH (A380)
            # (these models don't have Neutral - PH)
        },
    },
    0x3c => {
        Name => 'ExposureProgram',
        Priority => 0,
        PrintConv => \%sonyExposureProgram,
    },
    0x3d => { # (copied from CameraSettings, ref 12)
        Name => 'ImageStabilization',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x3f => { # (verified for A330/A380)
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW', #(NC)
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => {
        Name => 'SonyImageSize',
        PrintConv => {
            1 => 'Large',
            2 => 'Medium',
            3 => 'Small',
        },
    },
    0x55 => { # (copied from CameraSettings, ref 12)
        Name => 'AspectRatio',
        PrintConv => {
            1 => '3:2',
            2 => '16:9',
        },
    },
    0x56 => { # (copied from CameraSettings, ref 12)
        Name => 'Quality',
        PrintConv => {
            0 => 'RAW',
            2 => 'CRAW',
            34 => 'RAW + JPEG',
            35 => 'CRAW + JPEG',
            16 => 'Extra Fine',
            32 => 'Fine',
            48 => 'Standard',
        },
    },
    0x58 => { # (copied from CameraSettings, ref 12)
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            33 => '1/3 EV',
            50 => '1/2 EV',
        },
    },
    0x83 => { #PH
        Name => 'ColorSpace',
        PrintConv => {
            5 => 'Adobe RGB',
            6 => 'sRGB',
        },
    },
);

# more Camera settings (ref PH)
# This was decoded for the A55, but it seems to apply to the following models:
# A33, A35, A55, A450, A500, A550, A560, A580, NEX-3, NEX-5, NEX-C3 and NEX-VG10E
%Image::ExifTool::Sony::CameraSettings3 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int8u',
    NOTES => q{
        Camera settings for models such as the A33, A35, A55, A450, A500, A550,
        A560, A580, NEX-3, NEX-5, NEX-C3 and NEX-VG10E.
    },
    0x00 => { #12
        Name => 'ShutterSpeedSetting',
        Notes => 'used only in M and S exposure modes',
        ValueConv => '2 ** (6 - Image::ExifTool::Sony::SonyEv($val))',
        ValueConvInv => 'int((6 - log($val) / log(2)) * 8 + 0.5)',
        PrintConv => '$val == 64 ? "Bulb" : Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val =~ /Bulb/i ? 64 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x01 => { #12
        Name => 'ApertureSetting',
        Notes => 'used only in M and A exposure modes',
        ValueConv => '2 ** ((Image::ExifTool::Sony::SonyEv($val) - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x02 => {
        Name => 'ISOSetting',
        ValueConv => '($val and $val < 254) ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '($val and $val != 254) ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => {
            OTHER => sub {
                my ($val, $inv) = @_;
                return int($val + 0.5) unless $inv;
                return Image::ExifTool::IsFloat($val) ? $val : undef;
            },
            0 => 'Auto',
            254 => 'n/a', # get this for multi-shot noise reduction
        },
    },
    0x03 => { #12
        Name => 'ExposureCompensation',
        ValueConv => '($val - 128) / 24', #PH
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : $val',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x04 => { #12
        Name => 'DriveModeSet',
        # Same drivemode info is repeated in 0x0034, but with at least the following exceptions:
        # - 0x0034 not for A550 ? - seen "0"
        # - sweep panorama    (0x05=80): 0x0004=16 and 0x0034=213
        # - 3D sweep panorama (0x05=57): 0x0004=16 and 0x0034=214
        # - hand-held night   (0x05=56): 0x0004=16 and 0x0034=211
        # preliminary conclusion: 0x0004 is Drivemode as pre-set, but may be overruled by Scene/Panorama mode selections
        #                         0x0034 is Divemode as actually used
        PrintConv => {
            16 => 'Single Frame',
            33 => 'Continuous High', # also automatically selected for Scene mode Sports-action (0x05=52)
            34 => 'Continuous Low',
            48 => 'Speed Priority Continuous',
            81 => 'Self-timer 10 sec',
            82 => 'Self-timer 2 sec, Mirror Lock-up',
            113 => 'Continuous Bracketing 0.3 EV',
            117 => 'Continuous Bracketing 0.7 EV',
            145 => 'White Balance Bracketing Low',
            146 => 'White Balance Bracketing High',
            192 => 'Remote Commander',
        },
    },
    0x05 => { #12
        Name => 'ExposureProgram',
        # Camera exposure program/mode as selected with the Mode dial.
        # For SCN a further selection is done via the menu
        # Matches OK with 0xb023
        PrintConv => {                          # A580 Mode Dial setting:
             1 => 'Program AE',                 # P
             2 => 'Aperture-priority AE',       # A
             3 => 'Shutter speed priority AE',  # S
             4 => 'Manual',                     # M
             5 => 'Cont. Priority AE',          # (A35)
            16 => 'Auto',                       # AUTO
            17 => 'Auto No Flash',              # "flash strike-out" symbol
            49 => 'Portrait',                   # SCN
            50 => 'Landscape',                  # SCN
            51 => 'Macro',                      # SCN
            52 => 'Sports',                     # SCN
            53 => 'Sunset',                     # SCN
            54 => 'Night view',                 # SCN
            55 => 'Night view/portrait',        # SCN
            56 => 'Handheld Night Shot',        # SCN (also called "Hand-held Twilight")
            57 => '3D Sweep Panorama',          # "Panorama" symbol
            65 => 'Auto Advanced',              # (A35)
            80 => 'Sweep Panorama',             # "Panorama" symbol
            # 128-138 are A35 picture effects (combined SCN/Picture effect mode dial position)
            128 => 'Toy Camera',
            129 => 'Pop Color',
            130 => 'Posterization',
            131 => 'Posterization B/W',
            132 => 'Retro Photo',
            133 => 'High-key',
            134 => 'Partial Color Red',
            135 => 'Partial Color Green',
            136 => 'Partial Color Blue',
            137 => 'Partial Color Yellow',
            138 => 'High Contrast Monochrome',
        },
    },
    0x06 => { #12
        Name => 'FocusMode',
        PrintConv => {
            17 => 'AF-S',
            18 => 'AF-C',
            19 => 'AF-A',
            32 => 'Manual',
        },
    },
    0x07 => { #12
        Name => 'MeteringMode',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted average',
            3 => 'Spot',
        },
    },
    0x09 => { #12
        Name => 'SonyImageSize',
        # below values seen for 16MP A580; maybe different for 12MP, 14MP ?
        PrintConv => {
           21 => 'Large (3:2)',    # A580: 16M  (4912 x 3264 pixels)
           22 => 'Medium (3:2)',   # A580: 8.4M (3568 x 2368 pixels)
           23 => 'Small (3:2)',    # A580: 4.0M (2448 x 1624 pixels)
           25 => 'Large (16:9)',   # A580: 14M  (4912 x 2760 pixels)
           26 => 'Medium (16:9)',  # A580: 7.1M (3568 x 2000 pixels)
           27 => 'Small (16:9)',   # A580: 3.4M (2448 x 1376 pixels)
        },
    },
    0x0a => { #12
        Name => 'AspectRatio',
        # normally 4 for A580 3:2 ratio images
        # seen 8 when selecting 16:9 via menu, and when selecting Panorama mode
        PrintConv => {
            4 => '3:2',
            8 => '16:9',
        },
    },
    0x0b => { #12
        Name => 'Quality',
        PrintConv => {
            2 => 'RAW',
            4 => 'RAW + JPEG',
            6 => 'Fine',
            7 => 'Standard',
        },
    },
    0x0c => {
        Name => 'DynamicRangeOptimizerSetting',
        PrintConv => {
            1 => 'Off',
            16 => 'On (Auto)',
            17 => 'On (Manual)',
        },
    },
    0x0d => 'DynamicRangeOptimizerLevel',
    0x0e => { #12
        Name => 'ColorSpace',
        PrintConv => {
            1 => 'sRGB',
            2 => 'AdobeRGB',
        },
    },
    0x0f => { #12
        Name => 'CreativeStyleSetting',
        PrintConvColumns => 2,
        PrintConv => {
            16 => 'Standard',
            32 => 'Vivid',
            64 => 'Portrait',
            80 => 'Landscape',
            96 => 'B&W',
            160 => 'Sunset',
        },
    },
    0x16 => { #12
        Name => 'WhiteBalanceSetting',
        # many guessed, based on "logical system" as observed for Daylight and Shade and steps of 16 between the modes
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x10 => 'Auto (-3)', #(NC)
            0x11 => 'Auto (-2)', #(NC)
            0x12 => 'Auto (-1)', #(NC)
            0x13 => 'Auto (0)',
            0x14 => 'Auto (+1)', #(NC)
            0x15 => 'Auto (+2)', #(NC)
            0x16 => 'Auto (+3)', #(NC)
            0x20 => 'Daylight (-3)',
            0x21 => 'Daylight (-2)', #(NC)
            0x22 => 'Daylight (-1)', #(NC)
            0x23 => 'Daylight (0)',
            0x24 => 'Daylight (+1)',
            0x25 => 'Daylight (+2)',
            0x26 => 'Daylight (+3)',
            0x30 => 'Shade (-3)', #(NC)
            0x31 => 'Shade (-2)', #(NC)
            0x32 => 'Shade (-1)', #(NC)
            0x33 => 'Shade (0)',
            0x34 => 'Shade (+1)', #(NC)
            0x35 => 'Shade (+2)', #(NC)
            0x36 => 'Shade (+3)',
            0x40 => 'Cloudy (-3)', #(NC)
            0x41 => 'Cloudy (-2)', #(NC)
            0x42 => 'Cloudy (-1)', #(NC)
            0x43 => 'Cloudy (0)',
            0x44 => 'Cloudy (+1)', #(NC)
            0x45 => 'Cloudy (+2)', #(NC)
            0x46 => 'Cloudy (+3)', #(NC)
            0x50 => 'Tungsten (-3)', #(NC)
            0x51 => 'Tungsten (-2)', #(NC)
            0x52 => 'Tungsten (-1)', #(NC)
            0x53 => 'Tungsten (0)',
            0x54 => 'Tungsten (+1)', #(NC)
            0x55 => 'Tungsten (+2)', #(NC)
            0x56 => 'Tungsten (+3)', #(NC)
            0x60 => 'Fluorescent (-3)', #(NC)
            0x61 => 'Fluorescent (-2)', #(NC)
            0x62 => 'Fluorescent (-1)', #(NC)
            0x63 => 'Fluorescent (0)',
            0x64 => 'Fluorescent (+1)', #(NC)
            0x65 => 'Fluorescent (+2)', #(NC)
            0x66 => 'Fluorescent (+3)', #(NC)
            0x70 => 'Flash (-3)', #(NC)
            0x71 => 'Flash (-2)', #(NC)
            0x72 => 'Flash (-1)', #(NC)
            0x73 => 'Flash (0)',
            0x74 => 'Flash (+1)', #(NC)
            0x75 => 'Flash (+2)', #(NC)
            0x76 => 'Flash (+3)', #(NC)
            0xa3 => 'Custom (0)',
            0xf3 => '5500 K',
        },
    },
    0x20 => { #12
        Name => 'FlashMode',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Flash Off',
            16 => 'Autoflash',
            17 => 'Fill-flash',
            18 => 'Slow Sync',
            19 => 'Rear Sync',
            20 => 'Wireless',
        },
    },
    0x21 => { #12
        Name => 'FlashControl',
        PrintConv => {
            1 => 'ADI Flash',
            2 => 'Pre-flash TTL',
        },
    },
    0x23 => { #12
        Name => 'FlashExposureCompSet',
        Description => 'Flash Exposure Comp. Setting',
        # (as pre-selected by the user, not zero if flash didn't fire)
        ValueConv => '($val - 128) / 24', #PH
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : $val',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x24 => {
        Name => 'AFAreaMode',
        PrintConv => {
            1 => 'Wide',
            2 => 'Spot',
            3 => 'Local',
            4 => 'Flexible', #12
            # (Flexible Spot is a grid of 17x11 points for the NEX-5)
        },
    },
    0x25 => { #12
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            1 => 'Off',
            16 => 'On',  # (unused or dark subject)
        },
    },
    0x26 => { #12
        Name => 'HighISONoiseReduction',
        PrintConv => {
            16 => 'Low',
            19 => 'Auto',
        },
    },
    0x27 => { #12
        Name => 'SmileShutterMode',
        PrintConv => {
            17 => 'Slight Smile',
            18 => 'Normal Smile',
            19 => 'Big Smile',
        },
    },
    0x28 => { #12
        Name => 'RedEyeReduction',
        PrintConv => {
            1 => 'Off',
            16 => 'On',
        },
    },
    0x2d => {
        Name => 'AutoHDR',
        PrintConv => {
            1 => 'Off',
            16 => 'On (Auto)',
            17 => 'On (Manual)',
        },
    },
    0x2e => {
        Name => 'AutoHDRLevel',
        PrintConvColumns => 2,
        PrintConv => {
            33 => '1 EV',
            35 => '2 EV',
            37 => '3 EV',
            39 => '4 EV',
            40 => '5 EV',
            41 => '6 EV',
        },
    },
    0x2f => { #12 (not sure what is difference with 0x85)
        Name => 'ViewingMode',
        PrintConv => {
            16 => 'ViewFinder',
            33 => 'Focus Check Live View',
            34 => 'Quick AF Live View',
        },
    },
    0x30 => { #12
        Name => 'FaceDetection',
        PrintConv => {
            1 => 'OFF',
            16 => 'ON',
        },
    },
    0x31 => { #12
        Name => 'SmileShutter',
        PrintConv => {
            1 => 'OFF',
            16 => 'ON',
        },
    },
    0x32 => { #12
        Name => 'SweepPanoramaSize',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            1 => 'Standard',
            2 => 'Wide',
        },
    },
    0x33 => { #12
        Name => 'SweepPanoramaDirection',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            1 => 'Right',
            2 => 'Left',
            3 => 'Up',
            4 => 'Down',
        },
    },
    0x34 => { #12
        Name => 'DriveModeUsed',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            16 => 'Single Frame',
            33 => 'Continuous High', # also automatically selected for Scene mode Sports-action (0x05=52)
            34 => 'Continuous Low',
            48 => 'Speed Priority Continuous',
            81 => 'Self-timer 10 sec',
            82 => 'Self-timer 2 sec, Mirror Lock-up',
            113 => 'Continuous Bracketing 0.3 EV',
            117 => 'Continuous Bracketing 0.7 EV',
            145 => 'White Balance Bracketing Low',
            146 => 'White Balance Bracketing High',
            192 => 'Remote Commander',
            209 => 'Continuous - HDR',
            210 => 'Continuous - Multi Frame NR',
            211 => 'Continuous - Handheld Night Shot', # (also called "Hand-held Twilight")
            213 => 'Continuous - Sweep Panorama',
            214 => 'Continuous - 3D Sweep Panorama',
        },
    },
    0x35 => {
        Name => 'MultiFrameNoiseReduction',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a', # seen for A450/A500/A550
            1 => 'Off',
            16 => 'On',
            255 => 'None', # seen for NEX-3/5/C3
        },
    },
    0x36 => { #12 (not 100% sure about this one)
        Name => 'LiveViewAFMethod',
        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550))$/',
        PrintConv => {
            0 => 'n/a',
            1 => 'Phase-detect AF',
            2 => 'Contrast AF',
            # Contrast AF is only available with SSM/SAM lenses and in Focus Check LV,
            # NOT in Quick AF LV, and is automatically set when mounting SSM/SAM lens
            # - changes into Phase-AF when switching to Quick AF LV.
        },
    },
    0x38 => { #12
        Name => '3DPanoramaSize',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a',
            1 => 'Standard',
            2 => 'Wide',
            3 => '16:9',
        },
    },
    0x84 => { #12 (not 100% sure about this one)
        Name => 'LiveViewMetering',
        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550))$/',
        PrintConv => {
            0 => 'n/a',
            16 => '40 Segment',             # DSLR with LiveView/OVF switch in OVF position 
            32 => '1200-zone Evaluative',   # SLT, or DSLR with LiveView/OVF switch in LiveView position 
        },
    },
    0x85 => { #12 (not sure what is difference with 0x2f)
        Name => 'ViewingMode2',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a',
            16 => 'Viewfinder',
            33 => 'Focus Check Live View',
            34 => 'Quick AF Live View',
        },
    },
    0x87 => { #12
        Name => 'FlashAction',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/', #seen 0 for A550, so better exclude ?
        PrintConv => {
            1 => 'Did not fire',
            2 => 'Fired',
        },
    },
    0x8b => { #12
        Name => 'LiveViewFocusMode',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a',
            1 => 'AF',
            16 => 'Manual',
        },
    },
    0x10c => { #12
        Name => 'SequenceNumber',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/', #seen 18 for A550, so better exclude ?
        # normally 0; seen 1,2,3 for bracketing, 6 for Handheld Night Shot, 3 for HDR, 6 for MFNR
        PrintConv => {
            0 => 'Single',
            255 => 'n/a',
            OTHER => sub { shift }, # pass all other numbers straight through
        },
    },
    0x114 => { #12
        Name => 'ImageNumber',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/', #PH
        Format => 'int16u',
        ValueConv => '$val & 0x3fff', #PH (not sure what the upper 2 bits are for)
        ValueConvInv => '$val',
        PrintConv => 'sprintf("%.4d",$val)',
        PrintConvInv => '$val',
    },
);

# Camera settings for other models
%Image::ExifTool::Sony::CameraSettingsUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
);

# shot information (ref PH)
%Image::ExifTool::Sony::ShotInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    DATAMEMBER => [ 0x02, 0x30, 0x32 ],
    IS_SUBDIR => [ 0x48, 0x5e ],
    # 0x00 - byte order 'II'
    0x02 => {
        Name => 'FaceInfoOffset',
        Format => 'int16u',
        DataMember => 'FaceInfoOffset',
        Writable => 0,
        RawConv => '$$self{FaceInfoOffset} = $val',
    },
    0x06 => {
        Name => 'SonyDateTime',
        Format => 'string[20]',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x30 => { #Jeffrey Friedl
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        Format => 'int16u',
        RawConv => '$$self{FacesDetected} = $val',
    },
    0x32 => {
        Name => 'FaceInfoLength', # length of a single FaceInfo entry
        DataMember => 'FaceInfoLength',
        Format => 'int16u',
        Writable => 0,
        RawConv => '$$self{FaceInfoLength} = $val',
    },
    #0x34 => {
    #    # values: 'DC5303320222000', 'DC6303320222000' or 'DC7303320222000'
    #    Name => 'UnknownString',
    #    Format => 'string[16]',
    #    Unknown => 1,
    #},
    0x48 => { # (most models: DC5303320222000 and DC6303320222000)
        Name => 'FaceInfo1',
        Condition => q{
            $$self{FacesDetected} and
            $$self{FaceInfoOffset} == 0x48 and
            $$self{FaceInfoLength} == 0x20
        },
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::FaceInfo1' },
    },
    0x5e => { # (HX7V: DC7303320222000)
        Name => 'FaceInfo2',
        Condition => q{
            $$self{FacesDetected} and
            $$self{FaceInfoOffset} == 0x5e and
            $$self{FaceInfoLength} == 0x25
        },
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::FaceInfo2' },
    },
);

%Image::ExifTool::Sony::FaceInfo1 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x00 => {
        Name => 'Face1Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 1 ? undef : $val',
        Notes => q{
            top, left, height and width of detected face.  Coordinates are relative to
            the full-sized unrotated image, with increasing Y downwards
        },
    },
    0x20 => {
        Name => 'Face2Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    0x40 => {
        Name => 'Face3Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    0x60 => {
        Name => 'Face4Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    0x80 => {
        Name => 'Face5Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    0xa0 => {
        Name => 'Face6Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    0xc0 => {
        Name => 'Face7Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    0xe0 => {
        Name => 'Face8Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
);

%Image::ExifTool::Sony::FaceInfo2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x00 => {
        Name => 'Face1Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 1 ? undef : $val',
        Notes => q{
            top, left, height and width of detected face.  Coordinates are relative to
            the full-sized unrotated image, with increasing Y downwards
        },
    },
    0x25 => {
        Name => 'Face2Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    0x4a => {
        Name => 'Face3Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    0x6f => {
        Name => 'Face4Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    0x94 => {
        Name => 'Face5Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    0xb9 => {
        Name => 'Face6Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    0xde => {
        Name => 'Face7Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    0x103 => {
        Name => 'Face8Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
);

# panorama info for cameras such as the HX1, HX5, TX7 (ref 9/PH)
%Image::ExifTool::Sony::Panorama = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FORMAT => 'int32u',
    NOTES => q{
        Tags found only in panorama images from Sony cameras such as the HX1, HX5
        and TX7.  The width/height values of these tags are not affected by camera
        rotation -- the width is always the longer dimension.
    },
    # 0: 257
    1 => 'PanoramaFullWidth', # (including black/grey borders)
    2 => 'PanoramaFullHeight',
    3 => {
        Name => 'PanoramaDirection',
        PrintConv => {
            0 => 'Right to Left',
            1 => 'Left to Right',
        },
    },
    # crop area to remove black/grey borders from full image
    4 => 'PanoramaCropLeft',
    5 => 'PanoramaCropTop', #PH guess (NC)
    6 => 'PanoramaCropRight',
    7 => 'PanoramaCropBottom',
    # 8: 1728 (HX1), 1824 (HX5/TX7) (value8/value9 = 16/9)
    8 => 'PanoramaFrameWidth', #PH guess (NC)
    # 9: 972 (HX1), 1026 (HX5/TX7)
    9 => 'PanoramaFrameHeight', #PH guess (NC)
    # 10: 3200-3800 (HX1), 4000-4900 (HX5/TX7)
    10 => 'PanoramaSourceWidth', #PH guess (NC)
    # 11: 800-1800 (larger for taller panoramas)
    11 => 'PanoramaSourceHeight', #PH guess (NC)
    # 12-15: 0
);

# tag table for SRF0 IFD (ref 1)
%Image::ExifTool::Sony::SRF = (
    PROCESS_PROC => \&ProcessSRF,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SRF#', 2 => 'Camera' },
    NOTES => q{
        The maker notes in SRF (Sony Raw Format) images contain 7 IFD's with family
        1 group names SRF0 through SRF6.  SRF0 and SRF1 use the tags in this table,
        while SRF2 through SRF5 use the tags in the next table, and SRF6 uses
        standard EXIF tags.  All information other than SRF0 is encrypted, but
        thanks to Dave Coffin the decryption algorithm is known.  SRF images are
        written by the Sony DSC-F828 and DSC-V3.
    },
    # tags 0-1 are used in SRF1
    0 => {
        Name => 'SRF2Key',
        Notes => 'key to decrypt maker notes from the start of SRF2',
        RawConv => '$self->{SRF2Key} = $val',
    },
    1 => {
        Name => 'DataKey',
        Notes => 'key to decrypt the rest of the file from the end of the maker notes',
        RawConv => '$self->{SRFDataKey} = $val',
    },
    # SRF0 contains a single unknown tag with TagID 0x0003
);

# tag table for Sony RAW Format (ref 1)
%Image::ExifTool::Sony::SRF2 = (
    PROCESS_PROC => \&ProcessSRF,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SRF#', 2 => 'Camera' },
    NOTES => "These tags are found in the SRF2 through SRF5 IFD's.",
    # the following tags are used in SRF2-5
    2 => 'SRF6Offset', #PH
    # SRFDataOffset references 2220 bytes of unknown data for the DSC-F828 - PH
    3 => { Name => 'SRFDataOffset', Unknown => 1 }, #PH
    4 => { Name => 'RawDataOffset' }, #PH
    5 => { Name => 'RawDataLength' }, #PH
);

# tag table for Sony RAW 2 Format Private IFD (ref 1)
%Image::ExifTool::Sony::SR2Private = (
    PROCESS_PROC => \&ProcessSR2,
    WRITE_PROC => \&WriteSR2,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2', 2 => 'Camera' },
    NOTES => q{
        The SR2 format uses the DNGPrivateData tag to reference a private IFD
        containing these tags.  SR2 images are written by the Sony DSC-R1, but
        this information is also written to ARW images by other models.
    },
    0x7200 => {
        Name => 'SR2SubIFDOffset',
        # (adjusting offset messes up calculations for AdobeSR2 in DNG images)
        # Flags => 'IsOffset',
        # (can't set OffsetPair or else DataMember won't be set when writing)
        # OffsetPair => 0x7201,
        DataMember => 'SR2SubIFDOffset',
        RawConv => '$$self{SR2SubIFDOffset} = $val',
    },
    0x7201 => {
        Name => 'SR2SubIFDLength',
        # (can't set OffsetPair or else DataMember won't be set when writing)
        # OffsetPair => 0x7200,
        DataMember => 'SR2SubIFDLength',
        RawConv => '$$self{SR2SubIFDLength} = $val',
    },
    0x7221 => {
        Name => 'SR2SubIFDKey',
        Format => 'int32u',
        Notes => 'key to decrypt SR2SubIFD',
        DataMember => 'SR2SubIFDKey',
        RawConv => '$$self{SR2SubIFDKey} = $val',
        PrintConv => 'sprintf("0x%.8x", $val)',
    },
    0x7240 => { #PH
        Name => 'IDC_IFD',
        Groups => { 1 => 'SonyIDC' },
        Condition => '$$valPt !~ /^\0\0\0\0/',   # (just in case this could be zero)
        Flags => 'SubIFD',
        SubDirectory => {
            DirName => 'SonyIDC',
            TagTable => 'Image::ExifTool::SonyIDC::Main',
            Start => '$val',
        },
    },
    0x7241 => { #PH
        Name => 'IDC2_IFD',
        Groups => { 1 => 'SonyIDC' },
        Condition => '$$valPt !~ /^\0\0\0\0/',   # may be zero if dir doesn't exist
        Flags => 'SubIFD',
        SubDirectory => {
            DirName => 'SonyIDC2',
            TagTable => 'Image::ExifTool::SonyIDC::Main',
            Start => '$val',
            Base => '$start',
            MaxSubdirs => 20,   # (A900 has 10 null entries, but IDC writes only 1)
            RelativeBase => 1,  # needed to write SubIFD with relative offsets
        },
    },
    0x7250 => { #1
        Name => 'MRWInfo',
        Condition => '$$valPt !~ /^\0\0\0\0/',   # (just in case this could be zero)
        SubDirectory => {
            TagTable => 'Image::ExifTool::MinoltaRaw::Main',
        },
    },
);

%Image::ExifTool::Sony::SR2SubIFD = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2SubIFD', 2 => 'Camera' },
    SET_GROUP1 => 1, # set group1 name to directory name for all tags in table
    NOTES => 'Tags in the encrypted SR2SubIFD',
    0x7303 => 'WB_GRBGLevels', #1
    0x74c0 => { #PH
        Name => 'SR2DataIFD',
        Groups => { 1 => 'SR2DataIFD' }, # (needed to set SubIFD DirName)
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::SR2DataIFD',
            Start => '$val',
            MaxSubdirs => 20, # an A700 ARW has 14 of these! - PH
        },
    },
    0x7313 => 'WB_RGGBLevels', #6
    0x74a0 => 'MaxApertureAtMaxFocal', #PH
    0x74a1 => 'MaxApertureAtMinFocal', #PH
    0x7820 => 'WB_RGBLevelsDaylight', #6
    0x7821 => 'WB_RGBLevelsCloudy', #6
    0x7822 => 'WB_RGBLevelsTungsten', #6
    0x7825 => 'WB_RGBLevelsShade', #6
    0x7826 => 'WB_RGBLevelsFluorescent', #6
    0x7828 => 'WB_RGBLevelsFlash', #6
);

%Image::ExifTool::Sony::SR2DataIFD = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2DataIFD', 2 => 'Camera' },
    SET_GROUP1 => 1, # set group1 name to directory name for all tags in table
    # 0x7313 => 'WB_RGGBLevels', (duplicated in all SR2DataIFD's)
    0x7770 => { #PH
        Name => 'ColorMode',
        Priority => 0,
    },
);

# tags found in DSC-F1 PMP header (ref 10)
%Image::ExifTool::Sony::PMP = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FIRST_ENTRY => 0,
    NOTES => q{
        These tags are written in the proprietary-format header of PMP images from
        the DSC-F1.
    },
    8 => { #PH
        Name => 'JpgFromRawStart',
        Format => 'int32u',
        Notes => q{
            OK, not really a RAW file, but this mechanism is used to allow extraction of
            the JPEG image from a PMP file
        },
    },
    12 => { Name => 'JpgFromRawLength',Format => 'int32u' },
    22 => { Name => 'SonyImageWidth',  Format => 'int16u' },
    24 => { Name => 'SonyImageHeight', Format => 'int16u' },
    27 => {
        Name => 'Orientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 270 CW',#11
            2 => 'Rotate 180',
            3 => 'Rotate 90 CW',#11
        },
    },
    29 => {
        Name => 'ImageQuality',
        PrintConv => {
            8 => 'Snap Shot',
            23 => 'Standard',
            51 => 'Fine',
        },
    },
    # 40 => ImageWidth again (int16u)
    # 42 => ImageHeight again (int16u)
    52 => { Name => 'Comment',         Format => 'string[19]' },
    76 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'int8u[6]',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            my @a = split ' ', $val;
            $a[0] += $a[0] < 70 ? 2000 : 1900;
            sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', @a);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    84 => {
        Name => 'ModifyDate',
        Format => 'int8u[6]',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            my @a = split ' ', $val;
            $a[0] += $a[0] < 70 ? 2000 : 1900;
            sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', @a);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    102 => {
        Name => 'ExposureTime',
        Format => 'int16s',
        RawConv => '$val <= 0 ? undef : $val',
        ValueConv => '2 ** (-$val / 100)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    106 => { # (NC -- not written by DSC-F1)
        Name => 'FNumber',
        Format => 'int16s',
        RawConv => '$val <= 0 ? undef : $val',
        ValueConv => '$val / 100', # (likely wrong)
    },
    108 => { # (NC -- not written by DSC-F1)
        Name => 'ExposureCompensation',
        Format => 'int16s',
        RawConv => '($val == -1 or $val == -32768) ? undef : $val',
        ValueConv => '$val / 100', # (probably wrong too)
    },
    112 => { # (NC -- not written by DSC-F1)
        Name => 'FocalLength',
        Format => 'int16s',
        Groups => { 2 => 'Camera' },
        RawConv => '$val <= 0 ? undef : $val',
        ValueConv => '$val / 100',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    118 => {
        Name => 'Flash',
        Groups => { 2 => 'Camera' },
        PrintConv => { 0 => 'No Flash', 1 => 'Fired' },
    },
);

# Composite Sony tags
%Image::ExifTool::Sony::Composite = (
    GROUPS => { 2 => 'Camera' },
    FocusDistance => {
        Require => {
            0 => 'Sony:FocusPosition',
            1 => 'FocalLength',
        },
        Notes => 'distance in metres = FocusPosition * FocalLength / 1000',
        ValueConv => '$val >= 128 ? "inf" : $val * $val[1] / 1000',
        PrintConv => '$val eq "inf" ? $val : "$val m"',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Sony');

# fill in Sony LensType lookup based on Minolta values
{
    my $minoltaTypes = \%Image::ExifTool::Minolta::minoltaLensTypes;
    %sonyLensTypes = %$minoltaTypes;
    delete $$minoltaTypes{Notes};   # (temporarily)
    my $id;
    # 5-digit lens ID's are missing the last digit (usually "1") in the metadata for
    # some Sony models, so generate corresponding 4-digit entries for these cameras
    foreach $id (sort { $a <=> $b } keys %$minoltaTypes) {
        next if $id < 10000;
        my $sid = int($id/10);
        my $i;
        my $lens = $$minoltaTypes{$id};
        if ($sonyLensTypes{$sid}) {
            # put lens name with "or" first in list
            if ($lens =~ / or /) {
                my $tmp = $sonyLensTypes{$sid};
                $sonyLensTypes{$sid} = $lens;
                $lens = $tmp;
            }
            for (;;) {
                $i = ($i || 0) + 1;
                $sid = int($id/10) . ".$i";
                last unless $sonyLensTypes{$sid};
            }
        }
        $sonyLensTypes{$sid} = $lens;
    }
    $$minoltaTypes{Notes} = $sonyLensTypes{Notes}; # (restore original Notes)
}

#------------------------------------------------------------------------------
# Print Sony LensSpec value
# Inputs: 0) LensSpec numerical value
# Returns: converted LensSpec string (ie. "DT 18-55mm F3.5-5.6 SAM")
# Refs: http://equational.org/importphotos/alphalensinfo.html
#       http://www.dyxum.com/dforum/the-lens-information-different-from-lensid_topic37682.html
my @lensFeatures = (
    # lens features in the order they are added to the LensSpec string
    # (high byte of Mask/Bits represents byte 0 of LensSpec, low byte is byte 7)
    #  Mask   {  Bits     Name    Bits     Name  } Prefix flag
    # ------    ------    -----  ------    -----   -----------
    [ 0x0300, { 0x0100 => 'DT',  0x0300 => 'E'   }, 1 ],
    [ 0x000c, { 0x0004 => 'ZA',  0x0008 => 'G'   } ],
    [ 0x00e0, { 0x0020 => 'STF', 0x0040 => 'Reflex', 0x0060 => 'Macro', 0x0080 => 'Fisheye' } ],
    [ 0x0003, { 0x0001 => 'SSM', 0x0002 => 'SAM' } ],
    [ 0x8000, { 0x8000 => 'OSS' } ],
);
sub PrintLensSpec($)
{
    my $val = shift;
    # 0=flags1, 1=short focal, 2=long focal, 3=max aperture at short focal,
    # 4=max aperture at long focal, 5=flags2
    my ($f1, $sf, $lf, $sa, $la, $f2) = split ' ', $val;
    my ($rtnVal, $feature);
    # crude validation of focal length and aperture values
    if ($sf != 0 and $sa != 0 and ($lf == 0 or $lf >= $sf) and ($la == 0 or $la >= $sa)) {
        # use focal and aperture range if this is a zoom lens
        $sf .= '-' . $lf if $lf != $sf and $lf != 0;
        $sa .= '-' . $la if $sa != $la and $la != 0;
        $rtnVal = "${sf}mm F$sa";     # heart of LensSpec is a LensInfo string
        # loop through available lens features
        my $flags = hex($f1 . $f2);
        foreach $feature (@lensFeatures) {
            my $bits = $$feature[0] & $flags;
            next unless $bits or $$feature[1]{$bits};
            # add feature name as a prefix or suffix to the LensSpec
            my $str = $$feature[1]{$bits} || sprintf('Unknown(%.4x)',$bits);
            $rtnVal = $$feature[2] ? "$str $rtnVal" : "$rtnVal $str";
        }
    } else {
        $rtnVal = "Unknown ($val)";
    }
    return $rtnVal;
}
# inverse conversion
sub PrintInvLensSpec($)
{
    my $val = shift;
    return $1 if $val =~ /Unknown ?\((.*)\)/i;
    my ($sf, $lf, $sa, $la) = Image::ExifTool::Exif::GetLensInfo($val);
    $sf or return undef;
    # fixed focal length and aperture have zero for 2nd number
    $lf = 0 if $lf == $sf;
    $la = 0 if $la == $sa;
    my $flags = 0;
    my ($feature, $bits);
    foreach $feature (@lensFeatures) {
        foreach $bits (keys %{$$feature[1]}) {
            # set corresponding flag bits for each feature name found
            my $name = $$feature[1]{$bits};
            $val =~ /\b$name\b/i and $flags |= $bits;
        }
    }
    return sprintf "%.2x $sf $lf $sa $la %.2x", $flags>>8, $flags&0xff;
}

#------------------------------------------------------------------------------
# Convert from integer EV*8 value to nearest 1/2 or 1/3 EV
# Inputs: 0) integer EV*8 value (must be positive)
# Returns: EV rounded to nearest 1/2 or 1/3 step
sub SonyEv($)
{
    my $ev = shift() / 8;
    my $ev2 = int($ev * 2 + 0.5) / 2;   # round to nearest 1/2 EV
    my $ev3 = int($ev * 3 + 0.5) / 3;   # round to nearest 1/3 EV
    return(abs($ev-$ev2) < abs($ev-$ev3) ? $ev2 : $ev3);
}

#------------------------------------------------------------------------------
# Read Sony DSC-F1 PMP file
# Inputs: 0) ExifTool object ref, 1) dirInfo ref
# Returns: 1 on success when reading, 0 if this isn't a valid PMP file
sub ProcessPMP($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    $raf->Read($buff, 128) == 128 or return 0;
    # validate header length (124 bytes)
    $buff =~ /^.{8}\0{3}\x7c.{112}\xff\xd8\xff\xdb$/s or return 0;
    $exifTool->SetFileType();
    SetByteOrder('MM');
    $exifTool->FoundTag(Make => 'Sony');
    $exifTool->FoundTag(Model => 'DSC-F1');
    # extract information from 124-byte header
    my $tagTablePtr = GetTagTable('Image::ExifTool::Sony::PMP');
    my %dirInfo = ( DataPt => \$buff, DirName => 'PMP' );
    $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
    # process JPEG image
    $raf->Seek(124, 0);
    $$dirInfo{Base} = 124;
    $exifTool->ProcessJPEG($dirInfo);
    return 1;
}

#------------------------------------------------------------------------------
# Decrypt/Encrypt Sony data (ref 1) (reversible encryption)
# Inputs: 0) data reference, 1) start offset, 2) data length, 3) decryption key
# Returns: nothing (original data buffer is updated with decrypted data)
# Notes: data length should be a multiple of 4
sub Decrypt($$$$)
{
    my ($dataPt, $start, $len, $key) = @_;
    my ($i, $j, @pad);
    my $words = int ($len / 4);

    for ($i=0; $i<4; ++$i) {
        my $lo = ($key & 0xffff) * 0x0edd + 1;
        my $hi = ($key >> 16) * 0x0edd + ($key & 0xffff) * 0x02e9 + ($lo >> 16);
        $pad[$i] = $key = (($hi & 0xffff) << 16) + ($lo & 0xffff);
    }
    $pad[3] = ($pad[3] << 1 | ($pad[0]^$pad[2]) >> 31) & 0xffffffff;
    for ($i=4; $i<0x7f; ++$i) {
        $pad[$i] = (($pad[$i-4]^$pad[$i-2]) << 1 |
                    ($pad[$i-3]^$pad[$i-1]) >> 31) & 0xffffffff;
    }
    my @data = unpack("x$start N$words", $$dataPt);
    for ($i=0x7f,$j=0; $j<$words; ++$i,++$j) {
        $data[$j] ^= $pad[$i & 0x7f] = $pad[($i+1) & 0x7f] ^ $pad[($i+65) & 0x7f];
    }
    substr($$dataPt, $start, $words*4) = pack('N*', @data);
}

#------------------------------------------------------------------------------
# Set the ARW file type and decide between SubIFD and A100DataOffset
# Inputs: 0) ExifTool object ref, 1) reference to tag 0x14a raw data
# Returns: true if tag 0x14a is a SubIFD, false otherwise
sub SetARW($$)
{
    my ($exifTool, $valPt) = @_;

    # assume ARW for now -- SR2's get identified when FileFormat is parsed
    $exifTool->OverrideFileType($$exifTool{TIFF_TYPE} = 'ARW');

    # this should always be a SubIFD for models other than the A100
    return 1 unless $$exifTool{Model} eq 'DSLR-A100' and length $$valPt == 4;

    # for the A100, IFD0 tag 0x14a is either a pointer to the raw data if this is
    # an original image, or a SubIFD offset if the image was edited by Sony IDC,
    # so assume it points to the raw data if it isn't a valid IFD (this assumption
    # will be checked later when we try to parse the SR2Private directory)
    my %subdir = (
        DirStart => Get32u($valPt, 0),
        Base     => 0,
        RAF      => $$exifTool{RAF},
        AllowOutOfOrderTags => 1, # doh!
    );
    return Image::ExifTool::Exif::ValidateIFD(\%subdir);
}

#------------------------------------------------------------------------------
# Finish writing ARW image, patching necessary Sony quirks, etc
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) EXIF data ref, 3) image data reference
# Returns: undef on success, error string otherwise
# Notes: (it turns that all of this is for the A100 only)
sub FinishARW($$$$)
{
    my ($exifTool, $dirInfo, $dataPt, $imageData) = @_;

    # pre-scan IFD0 to get IFD entry offsets for each tag
    my $dataLen = length $$dataPt;
    return 'Truncated IFD0' if $dataLen < 2;
    my $n = Get16u($dataPt, 0);
    return 'Truncated IFD0' if $dataLen < 2 + 12 * $n;
    my ($i, %entry, $dataBlock, $pad, $dataOffset);
    for ($i=0; $i<$n; ++$i) {
        my $entry = 2 + $i * 12;
        $entry{Get16u($dataPt, $entry)} = $entry;
    }
    # fix up SR2Private offset and A100DataOffset (A100 only)
    if ($entry{0xc634} and $$exifTool{MRWDirData}) {
        return 'Unexpected MRW block' unless $$exifTool{Model} eq 'DSLR-A100';
        return 'Missing A100DataOffset' unless $entry{0x14a} and $$exifTool{A100DataOffset};
        # account for total length of image data
        my $totalLen = 8 + $dataLen;
        if (ref $imageData) {
            foreach $dataBlock (@$imageData) {
                my ($pos, $size, $pad) = @$dataBlock;
                $totalLen += $size + $pad;
            }
        }
        # align MRW block on an even 4-byte boundary
        my $remain = $totalLen & 0x03;
        $pad = 4 - $remain and $totalLen += $pad if $remain;
        # set offset for the MRW directory data
        Set32u($totalLen, $dataPt, $entry{0xc634} + 8);
        # also pad MRWDirData data to an even 4 bytes (just to be safe)
        $remain = length($$exifTool{MRWDirData}) & 0x03;
        $$exifTool{MRWDirData} .= "\0" x (4 - $remain) if $remain;
        $totalLen += length $$exifTool{MRWDirData};
        # fix up A100DataOffset
        $dataOffset = $$exifTool{A100DataOffset};
        Set32u($totalLen, $dataPt, $entry{0x14a} + 8);
    }
    # patch double-referenced and incorrectly-sized A100 PreviewImage
    if ($entry{0x201} and $$exifTool{A100PreviewStart} and
        $entry{0x202} and $$exifTool{A100PreviewLength})
    {
        Set32u($$exifTool{A100PreviewStart}, $dataPt, $entry{0x201} + 8);
        Set32u($$exifTool{A100PreviewLength}, $dataPt, $entry{0x202} + 8);
    }
    # write TIFF IFD structure
    my $outfile = $$dirInfo{OutFile};
    my $header = GetByteOrder() . Set16u(0x2a) . Set32u(8);
    Write($outfile, $header, $$dataPt) or return 'Error writing';
    # copy over image data
    if (ref $imageData) {
        $exifTool->CopyImageData($imageData, $outfile) or return 'Error copying image data';
    }
    # write MRW data if necessary
    if ($$exifTool{MRWDirData}) {
        Write($outfile, "\0" x $pad) if $pad;   # write padding if necessary
        Write($outfile, $$exifTool{MRWDirData});
        delete $$exifTool{MRWDirData};
        # set TIFF_END to copy over the MRW image data
        $$exifTool{TIFF_END} = $dataOffset if $dataOffset;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Process SRF maker notes
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessSRF($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart};
    my $verbose = $exifTool->Options('Verbose');

    # process IFD chain
    my ($ifd, $success);
    for ($ifd=0; ; ) {
        # switch tag table for SRF2-5 and SRF6
        if ($ifd == 2) {
            $tagTablePtr = GetTagTable('Image::ExifTool::Sony::SRF2');
        } elsif ($ifd == 6) {
            # SRF6 uses standard EXIF tags
            $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
        }
        my $srf = $$dirInfo{DirName} = "SRF$ifd";
        $exifTool->{SET_GROUP1} = $srf;
        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $tagTablePtr);
        delete $exifTool->{SET_GROUP1};
        last unless $success;
#
# get pointer to next IFD
#
        my $count = Get16u($dataPt, $$dirInfo{DirStart});
        my $dirEnd = $$dirInfo{DirStart} + 2 + $count * 12;
        last if $dirEnd + 4 > length($$dataPt);
        my $nextIFD = Get32u($dataPt, $dirEnd);
        last unless $nextIFD;
        $nextIFD -= $$dirInfo{DataPos}; # adjust for position of makernotes data
        $$dirInfo{DirStart} = $nextIFD;
#
# decrypt next IFD data if necessary
#
        ++$ifd;
        my ($key, $len);
        if ($ifd == 1) {
            # get the key to decrypt IFD1
            my $cp = $start + 0x8ddc;    # why?
            my $ip = $cp + 4 * unpack("x$cp C", $$dataPt);
            $key = unpack("x$ip N", $$dataPt);
            $len = $cp + $nextIFD;  # decrypt up to $cp
        } elsif ($ifd == 2) {
            # get the key to decrypt IFD2
            $key = $exifTool->{SRF2Key};
            $len = length($$dataPt) - $nextIFD; # decrypt rest of maker notes
        } else {
            next;   # no decryption needed
        }
        # decrypt data
        Decrypt($dataPt, $nextIFD, $len, $key) if defined $key;
        next unless $verbose > 2;
        # display decrypted data in verbose mode
        $exifTool->VerboseDir("Decrypted SRF$ifd", 0, $nextIFD + $len);
        $exifTool->VerboseDump($dataPt,
            Prefix => "$exifTool->{INDENT}  ",
            Start => $nextIFD,
            DataPos => $$dirInfo{DataPos},
        );
    }
}

#------------------------------------------------------------------------------
# Write SR2 data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success when reading, or SR2 directory or undef when writing
sub WriteSR2($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    $exifTool or return 1;      # allow dummy access
    my $buff = '';
    $$dirInfo{OutFile} = \$buff;
    return ProcessSR2($exifTool, $dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Read/Write SR2 IFD and its encrypted subdirectories
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success when reading, or SR2 directory or undef when writing
sub ProcessSR2($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dataLen = $$dirInfo{DataLen} || length $$dataPt;
    my $base = $$dirInfo{Base} || 0;
    my $outfile = $$dirInfo{OutFile};

    # clear SR2 member variables to be safe
    delete $$exifTool{SR2SubIFDOffset};
    delete $$exifTool{SR2SubIFDLength};
    delete $$exifTool{SR2SubIFDKey};

    # make sure we have the first 4 bytes available to test directory type
    my $buff;
    if ($dataLen < 4 and $raf) {
        my $pos = $dataPos + ($$dirInfo{DirStart}||0) + $base;
        if ($raf->Seek($pos, 0) and $raf->Read($buff, 4) == 4) {
            $dataPt = \$buff;
            undef $$dirInfo{DataPt};    # must load data from file
            $raf->Seek($pos, 0);
        }
    }
    # this may either be a normal IFD, or a MRW data block
    # (only original ARW images from the A100 use the MRW block)
    my $dataOffset;
    if ($dataPt and $$dataPt =~ /^\0MR[IM]/) {
        my ($err, $srfPos, $srfLen, $dataOffset);
        $dataOffset = $$exifTool{A100DataOffset};
        if ($dataOffset) {
            # save information about the RAW data trailer so it will be preserved
            $$exifTool{KnownTrailer} = { Name => 'A100 RAW Data', Start => $dataOffset };
        } else {
            $err = 'A100DataOffset tag is missing from A100 ARW image';
        }
        $raf or $err = 'Unrecognized SR2 structure';
        unless ($err) {
            $srfPos = $raf->Tell();
            $srfLen = $dataOffset - $srfPos;
            unless ($srfLen > 0 and $raf->Read($buff, $srfLen) == $srfLen) {
                $err = 'Error reading MRW directory';
            }
        }
        if ($err) {
            $outfile and $exifTool->Error($err), return undef;
            $exifTool->Warn($err);
            return 0;
        }
        my %dirInfo = ( DataPt => \$buff );
        require Image::ExifTool::MinoltaRaw;
        if ($outfile) {
            # save MRW data to be written last
            $$exifTool{MRWDirData} = Image::ExifTool::MinoltaRaw::WriteMRW($exifTool, \%dirInfo);
            return $$exifTool{MRWDirData} ? "\0\0\0\0\0\0" : undef;
        } else {
            if (not $outfile and $$exifTool{HTML_DUMP}) {
                $exifTool->HDump($srfPos, $srfLen, '[A100 SRF Data]');
            }
            return Image::ExifTool::MinoltaRaw::ProcessMRW($exifTool, \%dirInfo);
        }
    } elsif ($$exifTool{A100DataOffset}) {
        my $err = 'Unexpected A100DataOffset tag';
        $outfile and $exifTool->Error($err), return undef;
        $exifTool->Warn($err);
        return 0;
    }
    my $verbose = $exifTool->Options('Verbose');
    my $result;
    if ($outfile) {
        $result = Image::ExifTool::Exif::WriteExif($exifTool, $dirInfo, $tagTablePtr);
        return undef unless $result;
        $$outfile .= $result;

    } else {
        $result = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $tagTablePtr);
    }
    return $result unless $result and $$exifTool{SR2SubIFDOffset};
    # only take first offset value if more than one!
    my @offsets = split ' ', $exifTool->{SR2SubIFDOffset};
    my $offset = shift @offsets;
    my $length = $exifTool->{SR2SubIFDLength};
    my $key = $exifTool->{SR2SubIFDKey};
    my @subifdPos;
    if ($offset and $length and defined $key) {
        my $buff;
        # read encrypted SR2SubIFD from file
        if (($raf and $raf->Seek($offset+$base, 0) and
                $raf->Read($buff, $length) == $length) or
            # or read from data (when processing Adobe DNGPrivateData)
            ($offset - $dataPos >= 0 and $offset - $dataPos + $length < $dataLen and
                ($buff = substr($$dataPt, $offset - $dataPos, $length))))
        {
            Decrypt(\$buff, 0, $length, $key);
            # display decrypted data in verbose mode
            if ($verbose > 2 and not $outfile) {
                $exifTool->VerboseDir("Decrypted SR2SubIFD", 0, $length);
                $exifTool->VerboseDump(\$buff, Addr => $offset + $base);
            }
            my $num = '';
            my $dPos = $offset;
            for (;;) {
                my %dirInfo = (
                    Base => $base,
                    DataPt => \$buff,
                    DataLen => length $buff,
                    DirStart => $offset - $dPos,
                    DirName => "SR2SubIFD$num",
                    DataPos => $dPos,
                );
                my $subTable = GetTagTable('Image::ExifTool::Sony::SR2SubIFD');
                if ($outfile) {
                    my $fixup = new Image::ExifTool::Fixup;
                    $dirInfo{Fixup} = $fixup;
                    $result = $exifTool->WriteDirectory(\%dirInfo, $subTable);
                    return undef unless $result;
                    # save position of this SubIFD
                    push @subifdPos, length($$outfile);
                    # add this directory to the returned data
                    $$fixup{Start} += length($$outfile);
                    $$outfile .= $result;
                    $dirInfo->{Fixup}->AddFixup($fixup);
                } else {
                    $result = $exifTool->ProcessDirectory(\%dirInfo, $subTable);
                }
                last unless @offsets;
                $offset = shift @offsets;
                $num = ($num || 1) + 1;
            }

        } else {
            $exifTool->Warn('Error reading SR2 data');
        }
    }
    if ($outfile and @subifdPos) {
        # the SR2SubIFD must be padded to a multiple of 4 bytes for the encryption
        my $sr2Len = length($$outfile) - $subifdPos[0];
        if ($sr2Len & 0x03) {
            my $pad = 4 - ($sr2Len & 0x03);
            $sr2Len += $pad;
            $$outfile .= ' ' x $pad;
        }
        # save the new SR2SubIFD Length and Key to be used later for encryption
        $$exifTool{SR2SubIFDLength} = $sr2Len;
        my $newKey = $$exifTool{VALUE}{SR2SubIFDKey};
        $$exifTool{SR2SubIFDKey} = $newKey if defined $newKey;
        # update SubIFD pointers manually and add to fixup, and set SR2SubIFDLength
        my $n = Get16u($outfile, 0);
        my ($i, %found);
        for ($i=0; $i<$n; ++$i) {
            my $entry = 2 + 12 * $i;
            my $tagID = Get16u($outfile, $entry);
            # only interested in SR2SubIFDOffset (0x7200) and SR2SubIFDLength (0x7201)
            next unless $tagID == 0x7200 or $tagID == 0x7201;
            $found{$tagID} = 1;
            my $fmt = Get16u($outfile, $entry + 2);
            if ($fmt != 0x04) { # must be int32u
                $exifTool->Error("Unexpected format ($fmt) for SR2SubIFD tag");
                return undef;
            }
            if ($tagID == 0x7201) { # SR2SubIFDLength
                Set32u($sr2Len, $outfile, $entry + 8);
                next;
            }
            my $tag = 'SR2SubIFDOffset';
            my $valuePtr = @subifdPos < 2 ? $entry+8 : Get32u($outfile, $entry+8);
            my $pos;
            foreach $pos (@subifdPos) {
                Set32u($pos, $outfile, $valuePtr);
                $dirInfo->{Fixup}->AddFixup($valuePtr, $tag);
                undef $tag;
                $valuePtr += 4;
            }
        }
        unless ($found{0x7200} and $found{0x7201}) {
            $exifTool->Error('Missing SR2SubIFD tag');
            return undef;
        }
    }
    return $outfile ? $$outfile : $result;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Sony - Sony EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Sony maker notes EXIF meta information.

=head1 NOTES

Also see Minolta.pm since Sony DSLR models use structures originating from
Minolta.

=head1 AUTHOR

Copyright 2003-2012, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://homepage3.nifty.com/kamisaka/makernote/makernote_sony.htm>

=item L<http://www.klingebiel.com/tempest/hd/pmp.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Thomas Bodenmann, Philippe Devaux, Jens Duttke, Marcus
Holland-Moritz, Andrey Tverdokhleb, Rudiger Lange, Igal Milchtaich, Michael
Reitinger and Jos Roost for help decoding some tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sony Tags>,
L<Image::ExifTool::TagNames/Minolta Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
