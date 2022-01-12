$prog &HFF , &HE7 , &HD1 , &HFF                                  ' generated. Take care that the chip supports all fuse bytes.'  '******************************************************
'Projekt:           Nur Anzeige der Heizungsanlage am GLCD
'
' 14.06.2014        ==> alles in .BAS
'
'======================================================

'System-Einstellungen    ******************************************************************
$regfile "m644adef.dat"
'Angabe der Taktfrequenz (8Mhz)
$crystal = 3686400                                               '        ==> Achtung Fuse Bits auf interne 8 MHz einstellen
$hwstack = 40
$swstack = 16
$framesize = 32


'*********************************************************************************************************************************
'Hardware  ***********************************************************************************************************************
'*********************************************************************************************************************************

' PortD = Datenbyte  für GLCD (D0 - D7)
' PortA = Steuerbyte für GLCD (A1 - A7)
' PortC = Taster & Schalter   (C0 - C5)
' PortC = Quarz               (C6 - C7)
' PortB = B0=1-wire; B1=Busfreigabe B2=Sound B5-B7=Prog.-Schnittstelle

'-------------------------------1-wire Configuration---------------------------
'-------------------------------------------------------------------------------
Config 1wire = Portb.0                                           ' 1-Wire Signaldraht                                4k7pullup installiert

Config Pinb.1 = Input                                            '1-Wire Freigabe zum externen Temperatur-Messen    4k7pullup installiert

'-------------------------------Sound Configuration---------------------------
'-------------------------------------------------------------------------------
'Config Portb.2 = Output  A.0???                    ' Piezo Summer an 5Volt


'-------------------------------Display Configuration---------------------------
'-------------------------------------------------------------------------------
'Display_Pin 1 = GND
'Display_Pin 2 = 5V
'Display_Pin3 = Schleifer Poti 5K; Anfang=5V; Ende=Pin18;
'Display_Pin 4 = CD = DI Data/instruction    = A2
'Display_Pin 5 = RD     = R/W Read/Write     = A3
'Display_Pin 6 = ENABLE = E Chip Enable      = A4
'Display_Pin15 = CE2    = CS1  Chip 2 select = A7
'Display_Pin16 = CE     = CS1  Chip 1 select = A6
'Display_Pin17 = RESET  = RST reset          = A5
'Display_Pin19 = Beleuchtung +
'Display_Pin20 = Beleuchtung -               = A1

$lib "glcdks108.lbx"
Config Graphlcd = 128 * 64sed , Dataport = Portd , Controlport = Porta , Cd = 2 , Rd = 3 , Enable = 4 , Ce2 = 7 , Ce = 6 , Reset = 5

$include "Font8x8.font"                                          ' Zeichensatz für 8x8Punkt Zeichen
' Setfont Font8x8
'$include "6x8_Leo.font"
Setfont Font8x8


'-------------------------------Taster Configuration---------------------------
'-------------------------------------------------------------------------------
Config Pinc.0 = Input                                            ' Taster Anzeige " Blätter + "
Taster_zurueck Alias Pinc.0
Config Pinc.1 = Input                                            ' Taster Anzeige " Blätter - "
Taster_enter Alias Pinc.1
Config Pinc.2 = Input                                            ' Taster Anzeige " - "
Taster_plus Alias Pinc.2
Config Pinc.3 = Input                                            ' Taster Anzeige " + "
Taster_minus Alias Pinc.3
Config Pinc.4 = Input                                            ' Schalter Heizkreis Ein/Aus
Heizkreis_schalter Alias Pinc.4
Config Pinc.5 = Input                                            ' Schalter Ölbrenner Ein/Aus
Zeit_aus_schalter Alias Pinc.5
Portc = &HFF                                                     ' Taster Pull up

Dim Merker_taster_enter As Bit
Dim Merker_taster_zurueck As Bit
Dim Merker_taster_minus As Bit
Dim Merker_taster_plus As Bit

Config Debounce = 10

'-------------------------------1-wire Bus Kommandos ---------------------------
'-------------------------------------------------------------------------------
Const Skiprom = &HCC                                             ' Überspringe Rom kommando
Const Read_rom = &H33                                            ' Lese Rom
Const Matchrom = &H55                                            'Baustein auswählen
Const Convertt = &H44                                            ' Start Temperaturmessung
Const Read_ram = &HBE                                            'Lese Scratchpad Ram
Const Copy_ram = &H48                                            ' Schreibe Scratch pad Ram
Const Recall_ee = &HB8                                           ' Kopiere EEProm nach Ram
Const Read_power = &HB4                                          ' Abrage Spannung nur DS1820

'-------------------------------1-wire Busteilnehmer---------------------------
'-------------------------------------------------------------------------------
Dim Rom_4(8) As Byte
Rom_4(1) = 16 : Rom_4(2) = 246 : Rom_4(3) = 130 : Rom_4(4) = 225 : Rom_4(5) = 1 : Rom_4(6) = 8 : Rom_4(7) = 0 : Rom_4(8) = 104       'Boiler1 (oben)
Dim Rom_2(8) As Byte
Rom_2(1) = 16 : Rom_2(2) = 82 : Rom_2(3) = 143 : Rom_2(4) = 195 : Rom_2(5) = 2 : Rom_2(6) = 8 : Rom_2(7) = 0 : Rom_2(8) = 151       'Boiler2 (mitte)

Dim Rom_1(8) As Byte
Rom_1(1) = 16 : Rom_1(2) = 226 : Rom_1(3) = 92 : Rom_1(4) = 221 : Rom_1(5) = 1 : Rom_1(6) = 8 : Rom_1(7) = 0 : Rom_1(8) = 73       'Heizkreis Vorlauf
Dim Rom_3(8) As Byte
Rom_3(1) = 16 : Rom_3(2) = 126 : Rom_3(3) = 140 : Rom_3(4) = 227 : Rom_3(5) = 1 : Rom_3(6) = 8 : Rom_3(7) = 0 : Rom_3(8) = 134       'Heizkreis Rücklauf

Dim Rom_5(8) As Byte
Rom_5(1) = 16 : Rom_5(2) = 26 : Rom_5(3) = 170 : Rom_5(4) = 225 : Rom_5(5) = 1 : Rom_5(6) = 8 : Rom_5(7) = 0 : Rom_5(8) = 250       'Holzkessel Vorlauf
Dim Rom_27(8) As Byte
Rom_27(1) = 16 : Rom_27(2) = 26 : Rom_27(3) = 170 : Rom_27(4) = 225 : Rom_27(5) = 1 : Rom_27(6) = 8 : Rom_27(7) = 0 : Rom_27(8) = 250       'Holzkessel Vorlauf
Dim Rom_28(8) As Byte
Rom_28(1) = 16 : Rom_28(2) = 93 : Rom_28(3) = 163 : Rom_28(4) = 225 : Rom_28(5) = 1 : Rom_28(6) = 8 : Rom_28(7) = 0 : Rom_28(8) = 249       'Holzkessel Rücklauf  (Steuerung)

Dim Rom_9(8) As Byte
Rom_9(1) = 16 : Rom_9(2) = 13 : Rom_9(3) = 123 : Rom_9(4) = 227 : Rom_9(5) = 1 : Rom_9(6) = 8 : Rom_9(7) = 0 : Rom_9(8) = 176       'Puffer 1-1
Dim Rom_10(8) As Byte
Rom_10(1) = 16 : Rom_10(2) = 150 : Rom_10(3) = 117 : Rom_10(4) = 227 : Rom_10(5) = 1 : Rom_10(6) = 8 : Rom_10(7) = 0 : Rom_10(8) = 91       'Puffer 1-2
Dim Rom_20(8) As Byte
Rom_20(1) = 16 : Rom_20(2) = 118 : Rom_20(3) = 156 : Rom_20(4) = 227 : Rom_20(5) = 1 : Rom_20(6) = 8 : Rom_20(7) = 0 : Rom_20(8) = 91       'Puffer 1-3
Dim Rom_11(8) As Byte
Rom_11(1) = 16 : Rom_11(2) = 129 : Rom_11(3) = 84 : Rom_11(4) = 227 : Rom_11(5) = 1 : Rom_11(6) = 8 : Rom_11(7) = 0 : Rom_11(8) = 176       'Puffer 1-4
Dim Rom_12(8) As Byte
Rom_12(1) = 16 : Rom_12(2) = 181 : Rom_12(3) = 159 : Rom_12(4) = 227 : Rom_12(5) = 1 : Rom_12(6) = 8 : Rom_12(7) = 0 : Rom_12(8) = 211       'Puffer 1-5
Dim Rom_13(8) As Byte
Rom_13(1) = 16 : Rom_13(2) = 155 : Rom_13(3) = 94 : Rom_13(4) = 225 : Rom_13(5) = 1 : Rom_13(6) = 8 : Rom_13(7) = 0 : Rom_13(8) = 158       'Außentemperatur
Dim Rom_14(8) As Byte
Rom_14(1) = 16 : Rom_14(2) = 93 : Rom_14(3) = 143 : Rom_14(4) = 225 : Rom_14(5) = 1 : Rom_14(6) = 8 : Rom_14(7) = 0 : Rom_14(8) = 32       'Ölkessel


Dim Rom_15(8) As Byte
Rom_15(1) = 16 : Rom_15(2) = 165 : Rom_15(3) = 145 : Rom_15(4) = 195 : Rom_15(5) = 2 : Rom_15(6) = 8 : Rom_15(7) = 0 : Rom_15(8) = 190       'Puffer 2-1
Dim Rom_16(8) As Byte
Rom_16(1) = 16 : Rom_16(2) = 243 : Rom_16(3) = 225 : Rom_16(4) = 195 : Rom_16(5) = 2 : Rom_16(6) = 8 : Rom_16(7) = 0 : Rom_16(8) = 79       'Puffer 2-2
Dim Rom_17(8) As Byte
Rom_17(1) = 16 : Rom_17(2) = 106 : Rom_17(3) = 70 : Rom_17(4) = 195 : Rom_17(5) = 2 : Rom_17(6) = 8 : Rom_17(7) = 0 : Rom_17(8) = 10       'Puffer 2-3
Dim Rom_18(8) As Byte
Rom_18(1) = 16 : Rom_18(2) = 224 : Rom_18(3) = 169 : Rom_18(4) = 195 : Rom_18(5) = 2 : Rom_18(6) = 8 : Rom_18(7) = 0 : Rom_18(8) = 154       'Puffer 2-4




Dim Rom_121(8) As Byte
Rom_121(1) = 41 : Rom_121(2) = 52 : Rom_121(3) = 103 : Rom_121(4) = 8 : Rom_121(5) = 0 : Rom_121(6) = 0 : Rom_121(7) = 0 : Rom_121(8) = 78       '8xIO  chip 2.1
Dim Rom_122(8) As Byte
Rom_122(1) = 41 : Rom_122(2) = 139 : Rom_122(3) = 101 : Rom_122(4) = 8 : Rom_122(5) = 0 : Rom_122(6) = 0 : Rom_122(7) = 0 : Rom_122(8) = 238       '8xIO  chip 2.1
Dim Rom_123(8) As Byte
Rom_123(1) = 41 : Rom_123(2) = 229 : Rom_123(3) = 96 : Rom_123(4) = 8 : Rom_123(5) = 0 : Rom_123(6) = 0 : Rom_123(7) = 0 : Rom_123(8) = 236       '8xIO  chip 2.2   Relais für  Solaranlage
Dim Rom_124(8) As Byte
Rom_124(1) = 41 : Rom_124(2) = 183 : Rom_124(3) = 107 : Rom_124(4) = 8 : Rom_124(5) = 0 : Rom_124(6) = 0 : Rom_124(7) = 0 : Rom_124(8) = 220       '8xIO  chip 2.2   Relais für  Solaranlage

Dim Rom_141(8) As Byte
Rom_141(1) = 32 : Rom_141(2) = 66 : Rom_141(3) = 17 : Rom_141(4) = 14 : Rom_141(5) = 0 : Rom_141(6) = 0 : Rom_141(7) = 0 : Rom_141(8) = 80       '4xAD  chip 4.1   AD-Wandler für  Solarpanel
Dim Rom_142(8) As Byte
Rom_142(1) = 32 : Rom_142(2) = 41 : Rom_142(3) = 22 : Rom_142(4) = 14 : Rom_142(5) = 0 : Rom_142(6) = 0 : Rom_142(7) = 0 : Rom_142(8) = 58       '4xAD  chip 4.1   AD-Wandler für  Solarpanel






'*******************************************************************************
'Konfiguration  *********************************************************************
'*******************************************************************************

Dim Hkv_temp As Integer                                          ' Temperaturwert Heizkreisvorlauf
Dim Hkr_temp As Integer                                          ' Temperaturwert Heizkreisrücklauf

Dim Holzv_temp As Integer
Dim Holzr_temp As Integer

Dim Boi1_temp As Integer                                         ' Temperaturwert Brauchwasserboiler oben
Dim Boi2_temp As Integer                                         ' Temperaturwert Brauchwasserboiler mitte

Dim Pu31_temp As Integer                                         ' Temperaturwert Puffer3 (750l) oben
Dim Pu32_temp As Integer                                         ' Temperaturwert Puffer3 (750l) mitte
Dim Pu33_temp As Integer                                         ' Temperaturwert Puffer3 (750l) unten
Dim Pu11_temp As Integer                                         ' Temperaturwert Puffer1 (800l) oben
Dim Pu12_temp As Integer                                         ' Temperaturwert Puffer1 (800l) fast oben
Dim Pu13_temp As Integer                                         ' Temperaturwert Puffer1 (800l) mitte
Dim Pu14_temp As Integer                                         ' Temperaturwert Puffer1 (800l) fast unten
Dim Pu15_temp As Integer                                         ' Temperaturwert Puffer1 (800l) unten
Dim Pu21_temp As Integer                                         ' Temperaturwert Puffer2 (800l) oben
Dim Pu22_temp As Integer                                         ' Temperaturwert Puffer2 (800l) fast oben
Dim Pu23_temp As Integer                                         ' Temperaturwert Puffer2 (800l) mitte
Dim Pu24_temp As Integer                                         ' Temperaturwert Puffer2 (800l) fast unten
Dim Pu25_temp As Integer                                         ' Temperaturwert Puffer2 (800l) unten
Dim Holz_temp As Integer
Dim Oel_temp As Integer                                          ' Temperaturwert des Ölkessels
Dim Aussen_temp As Integer                                       ' Temperaturwert Außentemperatur
Dim Solar_panel_1 As Integer                                     ' Temperaturwert des Solarfeldes 1 (kälteste Platte)
Dim Solar_panel_2 As Integer                                     ' Temperaturwert des Solarfeldes 2
Dim Solar_panel_3 As Integer                                     ' Temperaturwert des Solarfeldes 3
Dim Solar_panel_4 As Integer                                     ' Temperaturwert des Solarfeldes 4
Dim Solar_panel_5 As Integer                                     ' Temperaturwert des Solarfeldes 5
Dim Solar_panel_6 As Integer                                     ' Temperaturwert des Solarfeldes 6
Dim Solar_panel_7 As Integer                                     ' Temperaturwert des Solarfeldes 7 (heißeste Platte)


Dim Relais_byte As Byte                                          ' Eingangsbyte zum Lesen der 1wire-Relais-Ausgangskarte
M1_inv_boiler_lp Alias Relais_byte.0
M2_inv_heizkreispumpe Alias Relais_byte.1
Y1_inv_boilervorrang Alias Relais_byte.2
Y2_inv_boilerbetrieb Alias Relais_byte.3
Y3_inv_heizkreisbetrieb Alias Relais_byte.4
Inv_rote_lampe Alias Relais_byte.5
M3_inv_holzkesselpumpe Alias Relais_byte.6
Inv_brennerschleife Alias Relais_byte.7

Dim Dcf_byte_in As Byte                                          ' Eingangsbyte zum Lesen der 1wire-DCF-Schnittstelle
' Dcf_byte.0 Eingang = ' Täglich,  von 22:00-06:00 wird 1 ausgegeben
' Dcf_byte.1 Eingang = ' Sonntags, von 06:00-07:00 wird 1 ausgegeben
' Dcf_byte.2 Ausgang = 0 ==> Rundfunk abschalten
' Dcf_byte.3 Ausgang = 0 ==> Internet abschalten
Dcf_zeit_bit0 Alias Dcf_byte_in.0
Dcf_datum_bit1 Alias Dcf_byte_in.1
Dim Inv_tv_abschalten As Bit : Inv_tv_abschalten = 1
Dim Inv_lan_abschalten As Bit : Inv_lan_abschalten = 1


Dim Solarbyte As Byte
' Bit_0 = M4 Solarpumpe               ( Ausgang low = Pumpe an)
' Bit_1 = Y4 Solarventil              ( Ausgang low = Ventil an = Puffer laden)
' Bit_2 = Zustand Boiler/Puffer laden ( Ausgang low = Puffer; high = Boiler)
' Bit_3 = Zustand Hot System          ( Ausganh high = System is Hot)
' Bit_4 = 1-wire Fehler                ( Ausganh high = Fehler>0)
' Bit_6 = Nur Boilerladung            ( Eingang; low = Es wird nur der Boiler geladen )
' Bit_7 = Solarsteuerung aktiv        ( Eingang; Ausgänge werden nur geschaltet, wenn Bit7 high ist)
M4_inv_solar_pumpe Alias Solarbyte.0
Y4_inv_puffer_laden Alias Solarbyte.1



Dim Mischer_byte As Byte
' Bit_0 -> Eingang an den Mischer => Mischersteuerung aktiv        ( Regler regelt, wenn Bit=high ist)
' Bit_1 -> Eingang an den Mischer => Mischer auf                   ( Wenn Bit.0=low und Bit.1=0 Mischer geht ganz auf; Wenn Bit.0=low und Bit.1=1 Mischer geht ganz zu)
' Bit_2 -> Ausgang des Mischers => Mischer ist ganz auf          ( Ausganh low = Mischer ist ganz auf)
' Bit_3 -> Ausgang des Mischers => Mischer ist ganz zu           ( Ausganh low = Mischer ist ganz auf)
' Bit_4 -> Ausgang des Mischers => 1-wire Fehler                 ( Ausganh low = Fehler>0)
' Bit_5 ->
' Bit_6 ->
' Bit_7 ->



'-------------------------------------------------------------------------------
'-------------------------------------------------------------------------------

' Betriebsarten
Dim Holzbetrieb As Bit
Dim Pufferbetrieb As Bit
Dim Oelbetrieb As Bit

' Zustände
Dim Heizschalter_und_zeit As Bit
Dim Energiequelle_on As Bit
Dim Boiler_von_puffer As Bit
Dim Boiler_laden As Bit
Dim Af_hk_off As Bit
Dim Hot_bekaempfung As Bit
Dim Hk_tagabschaltung As Bit
Dim Hk_nachtabschaltung As Bit
Dim Hk_zeit_abschaltung As Bit





'-------------------------------------------------------------------------------
'-------------------------------------------------------------------------------

Dim Ram(9) As Byte

Dim 1wire_fehler As Byte
Dim 1wire_fehlertext As String * 12

1wire_fehler = 0
Dim 1wire_freigabe_merker As Bit

Dim Anzeigeseite As Word
Dim Taster_gedrueckt As Bit
Dim Anzeige_ruecksprungzeit As Byte
Dim _sec_alt As Byte

Dim Bus_abfragezaehler As Byte
Dim Bus_sec_alt As Byte

Dim Merker_zeit_synchro As Bit
Dim Merker_datum_synchro As Bit
Dim Zeit_ist_aktuell As Bit

Dim Wochentag As Byte

Dim Bytetemp As Byte
Dim Bytetemp2 As Byte
Dim Temp_long As Long
Dim Temp1 As Integer
Dim Temp2 As Integer
Dim I As Byte






'------------[Initialisierung der internen Bascom Softclock Uhrenroutine]-------
'-------------------------------------------------------------------------------
Enable Interrupts
'[now init the clock]
Config Date = Dmy , Separator = .                                ' Datumsformat definieren z.B. 31.12.10
Config Clock = Soft                                              'Initialisiert die Bascom eigene Uhr Routine
' Achtung!!! Funktioniert nur, wenn an TOSC1 und TOSC2 ein 32.768 MHz Uhrenquarz angeschlossen ist.
'The above statement will bind in an ISR so you can not use the TIMER anymore!
Date$ = "08.08.11"                                               ' Vorauswahl des Datumwertes
Time$ = "08:00:00"                                               ' Vorauswahl des Zeitwertes
Wochentag = 7                                                    ' Sonntag

'-------------------------------------------------------------------------------



' ******************************************************************************
' ******************************************************************************

' +++++++++++++++++++++ Eram Werte definieren und laden +++++++++++++++++++++++++++++++++++++++

Dim Eram_dummy As Eram Byte                                      ' erstes Byte sollte als dummy stehen, da bei reset gelöscht wird
Dim Eram_programmierstart As Eram Byte                           ' Bit wird beim ersten Start nach der Programmierung gesetzt, um die Eramwerte zu laden
Dim Eram_boilersollmax As Eram Byte
Dim Eram_boilersollmin As Eram Byte
Dim Eram_holzbetriebswert As Eram Byte
Dim Eram_pufferbetriebswert As Eram Byte
Dim Eram_puffer2boilersoll As Eram Byte
Dim Eram_af_aus As Eram Byte
Dim Eram_software As Eram Byte
Dim Eram_rote_lampe As Eram Byte
Dim Eram_menue_tag_off As Byte
Dim Eram_menue_nacht_off As Byte
Dim Eram_bus_abfragezeit As Eram Byte
Dim Eram_auto_oel_modus As Eram Byte
Dim Eram_m1_modus As Eram Byte
Dim Eram_m2_modus As Eram Byte
Dim Eram_m3_modus As Eram Byte
Dim Eram_m4_modus As Eram Byte
Dim Eram_y1_modus As Eram Byte
Dim Eram_y2_modus As Eram Byte
Dim Eram_y3_modus As Eram Byte
Dim Eram_y4_modus As Eram Byte
Dim Eram_bs_modus As Eram Byte
Dim Eram_tv_modus As Eram Byte
Dim Eram_lan_modus As Eram Byte
Dim Eram_solar_modus As Eram Byte
Dim Eram_solar_nur_boiler As Eram Byte
Dim Eram_solarsteuerung_in_betrieb As Eram Byte
Dim Eram_mischer_in_betrieb As Eram Byte

Dim Programmierstart As Byte
Dim Boilersollmax As Byte
Dim Boilersollmin As Byte
Dim Holzbetriebswert As Byte
Dim Pufferbetriebswert As Byte
Dim Puffer2boilersoll As Byte
Dim Af_aus As Byte
Dim Software As Byte
Dim Rote_lampe As Byte
Dim Menue_tag_off As Byte
Dim Menue_nacht_off As Byte
Dim Bus_abfragezeit As Byte
Dim Auto_oel_modus As Byte
Dim M1_modus As Byte
Dim M2_modus As Byte
Dim M3_modus As Byte
Dim M4_modus As Byte
Dim Y1_modus As Byte
Dim Y2_modus As Byte
Dim Y3_modus As Byte
Dim Y4_modus As Byte
Dim Bs_modus As Byte
Dim Tv_modus As Byte
Dim Lan_modus As Byte
Dim Solar_modus As Byte
Dim Solar_nur_boiler As Byte
Dim Solarsteuerung_in_betrieb As Byte
Dim Mischer_in_betrieb As Byte

Programmierstart = Eram_programmierstart
If Programmierstart = 255 Then                                   ' ERAM Werte werden nach Programmierung definiert

Bytetemp = 55
Eram_boilersollmax = Bytetemp

Bytetemp = 37
Eram_boilersollmin = Bytetemp

Bytetemp = 60
Eram_holzbetriebswert = Bytetemp

Bytetemp = 55
Eram_pufferbetriebswert = Bytetemp

Bytetemp = 15
Eram_puffer2boilersoll = Bytetemp

Bytetemp = 18
Eram_af_aus = Bytetemp

Bytetemp = 0                                                     ' 0 = Steuerung ; 1 = Anzeige ; 2 = Solar (nicht Programiert)
Eram_software = Bytetemp

Bytetemp = 75
Eram_rote_lampe = Bytetemp

Bytetemp = 0
Eram_menue_tag_off = Bytetemp

Bytetemp = 1
Eram_menue_nacht_off = Bytetemp

Bytetemp = 5
Eram_bus_abfragezeit = Bytetemp                                  ' Zeit wie oft Bus abgefragt wird

Bytetemp = 0
Eram_auto_oel_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_m1_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_m2_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_m3_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_m4_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_y1_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_y2_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_y3_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_y4_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_bs_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_tv_modus = Bytetemp

Bytetemp = 2                                                     ' 0 = Aus; 1 = Ein; 2 = Auto
Eram_lan_modus = Bytetemp

Bytetemp = 1                                                     ' 0 = Aus; 1 = Ein; 2 = nur Boiler
Eram_solar_modus = Bytetemp

Bytetemp = 0                                                     ' 0 = Boiler + Puffer laden; 1 = nur Boiler laden
Eram_solar_nur_boiler = Bytetemp

Bytetemp = 1                                                     ' 0 = Solarsteuerung Aus; 1 = Solarsteuerung Ein
Eram_solarsteuerung_in_betrieb = Bytetemp

Bytetemp = 1                                                     ' 0 = Mischersteuerung Aus; 1 = Mischersteuerung Ein
Eram_mischer_in_betrieb = Bytetemp


Programmierstart = Programmierstart + 1
Eram_programmierstart = Programmierstart
End If

Boilersollmax = Eram_boilersollmax
Boilersollmin = Eram_boilersollmin
Holzbetriebswert = Eram_holzbetriebswert
Pufferbetriebswert = Eram_pufferbetriebswert
Puffer2boilersoll = Eram_puffer2boilersoll
Af_aus = Eram_af_aus
Software = Eram_software
Rote_lampe = Eram_rote_lampe
Menue_tag_off = Eram_menue_tag_off
Menue_nacht_off = Eram_menue_nacht_off
Bus_abfragezeit = Eram_bus_abfragezeit
Auto_oel_modus = Eram_auto_oel_modus
M1_modus = Eram_m1_modus
M2_modus = Eram_m2_modus
M3_modus = Eram_m3_modus
M4_modus = Eram_m4_modus
Y1_modus = Eram_y1_modus
Y2_modus = Eram_y2_modus
Y3_modus = Eram_y3_modus
Y4_modus = Eram_y4_modus
Bs_modus = Eram_bs_modus
Tv_modus = Eram_tv_modus
Lan_modus = Eram_lan_modus
Solar_modus = Eram_solar_modus
Solar_nur_boiler = Eram_solar_nur_boiler
Solarsteuerung_in_betrieb = Eram_solarsteuerung_in_betrieb
Mischer_in_betrieb = Eram_mischer_in_betrieb


' ******************************************************************************
' ********************** Anzeige zum Programmstart (Vorspann) ******************
' ******************************************************************************


Cls
Lcdat 2 , 1 , "Leo's Heizung"                                    ' Ausgabe an Position  Zeile,Pos,
Lcdat 3 , 1 , "Steuerung"
Lcdat 5 , 1 , "V7"
Lcdat 7 , 1 , "Stand 16.11.2014"
Wait 3
Cls

' ------------[Watchdog Config]-----------------------------------------------------

' Config Watchdog = 2048                       'Konfiguration des Watchdog mit reset after ca. 2048 mSec
' Start Watchdog                               'Nach der Konfiguration muss der Watchdog gestartet werden und vor Ablauf des Zählers zurückgesetzt werden.


1wire_fehler = 0
Anzeigeseite = 0


'*********************************************************************************************************************************
' ********************** Do  *****************************************************************************************************
'*********************************************************************************************************************************

Do


' *********************************************************************************************************************************
' ********************** Busteilnehmer abfragen ***********************************************************************************
' *********************************************************************************************************************************

'-------------------------------------------------------------------------------
' ---------------------  Bus nur Abfragen, wenn Bus_abfragezaehler = 0  --------

 If Bus_abfragezaehler > 0 Then Goto 1wire_lib_ende

'-------------------------------------------------------------------------------
' ---------------------  Prüfen, ob Bus frei ist  ------------------------------

If Anzeigeseite > 0 Then Goto 1wire_lib_ende                     ' Temperaturwerte am Bus wird nur abgefragt, wenn Anzeige = 0 (Startseite)

Config Pinb.1 = Input
If Pinb.1 = 0 Then                                               ' Bus ist belegt    A.7 hat Pull up nach 5V und wird von den anderen Teilnehmer nach 0V gezogen
1wire_freigabe_merker = 0
Goto 1wire_lib_ende
End If

If Pinb.1 = 1 Then                                               ' Bus ist frei
1wire_freigabe_merker = 1
Config Portb.1 = Output
Portb.1 = 0
End If

Lcdat 7 , 96 , ">"

'-------------------------------------------------------------------------------
' ---------------------  1-wire Messung Starten  -------------------------------

1wire_fehlertext = "            "
1wire_fehler = 0


1wreset                                                          ' Bus reset
    If Err = 1 Then                                              ' Bus auf Fehler prüfen
    Locate 4 , 12
    1wire_fehler = 255
    1wire_fehlertext = "Busfehler   "
    Goto Bus_freigeben
    End If

Waitms 100

1wwrite Skiprom                                                  ' Rom Adressierung überspringen --> alle ansprechen
1wwrite Convertt                                                 ' Start Temperaturmessung
 Waitms 100

'-------------------------------------------------------------------------------
' ---------------------  Messwert auslesen und verarbeiten  --------------------

'( Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Hkv_temp = 0
 1wverify Rom_1(1)                                               ' Den gewünschten Sensor auswählen
 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Hkv_temp = Makeint(ram(1) , Ram(2))
  Hkv_temp = Hkv_temp / 2                                        ' AusLesewert °C berechnen

  Else
    1wire_fehler = 1
    Hkv_temp = 0
    End If
 ' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Hkr_temp = 0
  1wverify Rom_3(1)                                              ' Den gewünschten Sensor auswählen
 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Hkr_temp = Makeint(ram(1) , Ram(2))
  Hkr_temp = Hkr_temp / 2                                        ' AusLesewert °C berechnen

  Else
    1wire_fehler = 3
    Hkr_temp = 0
    End If
')

 ' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Boi1_temp = 0
  1wverify Rom_4(1)                                              ' Den gewünschten Sensor auswählen
   If err = 1 then
   1wire_fehler = 4
   1wire_fehlertext = "Fehler Boi1 "
   Else

 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Boi1_temp = Makeint(ram(1) , Ram(2))
  Boi1_temp = Boi1_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 4
    1wire_fehlertext = "Fehler Boi1 "
    Boi1_temp = 0
  End If
  End if


' -----------------------------------------------------------------------------

  Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Boi2_temp = 0
  1wverify Rom_2(1)                                              ' Den gewünschten Sensor auswählen

   If err = 1 then
   1wire_fehler = 2
   1wire_fehlertext = "Fehler Boi2 "
   Else

 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Boi2_temp = Makeint(ram(1) , Ram(2))
  Boi2_temp = Boi2_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 2
    1wire_fehlertext = "Fehler Boi2 "
    Boi2_temp = 0
    End If
    End if

  ' -----------------------------------------------------------------------------

' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Holzv_temp = 0
  1wverify Rom_27(1)                                             ' Den gewünschten Sensor auswählen
   If err = 1 then
   1wire_fehler = 27
   1wire_fehlertext = "Fehler Holzv"
   Else

 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Holzv_temp = Makeint(ram(1) , Ram(2))
  Holzv_temp = Holzv_temp / 2                                    ' AusLesewert °C berechnen
  Holz_temp = Holzv_temp                                         ' Holzofen_warm aus Vorlauf

  Else
    1wire_fehler = 27
    1wire_fehlertext = "Fehler Holzv"
    Holzv_temp = 0
  End If
  End if

 ' -----------------------------------------------------------------------------
Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Holzr_temp = 0
  1wverify Rom_28(1)                                             ' Den gewünschten Sensor auswählen
   If err = 1 then
   1wire_fehler = 4
   1wire_fehlertext = "Fehler Holzr"
   Else

 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Holzr_temp = Makeint(ram(1) , Ram(2))
  Holzr_temp = Holzr_temp / 2                                    ' AusLesewert °C berechnen

  Else
    1wire_fehler = 18
    1wire_fehlertext = "Fehler Holzr"
    Holzr_temp = 0
  End If
  End if
 ' -----------------------------------------------------------------------------


 ' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu11_temp = 0
  1wverify Rom_9(1)                                              ' Den gewünschten Sensor auswählen
   If err = 1 then
   1wire_fehler = 9
   1wire_fehlertext = "Fehler PU11 "
   Else

 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu11_temp = Makeint(ram(1) , Ram(2))
  Pu11_temp = Pu11_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 9
    1wire_fehlertext = "Fehler PU11 "
    Pu11_temp = 0
  End If
  End if

 ' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu12_temp = 0
  1wverify Rom_10(1)                                             ' Den gewünschten Sensor auswählen
   If err = 1 then
   1wire_fehler = 10
   1wire_fehlertext = "Fehler PU12 "
   Else

 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu12_temp = Makeint(ram(1) , Ram(2))
  Pu12_temp = Pu12_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 10
    1wire_fehlertext = "Fehler PU12 "
    Pu12_temp = 0
  End If
  End if

 ' -----------------------------------------------------------------------------
 '(
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu13_temp = 0
  1wverify Rom_20(1)                                             ' Den gewünschten Sensor auswählen
1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu13_temp = Makeint(ram(1) , Ram(2))
  Pu13_temp = Pu13_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 20
    Pu13_temp = 0
  End If

 ' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu14_temp = 0
  1wverify Rom_11(1)                                             ' Den gewünschten Sensor auswählen
 1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu14_temp = Makeint(ram(1) , Ram(2))
  Pu14_temp = Pu14_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 11
    Pu14_temp = 0
  End If
')
 ' -----------------------------------------------------------------------------
'(
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu15_temp = 0
  1wverify Rom_12(1)                                             ' Den gewünschten Sensor auswählen
1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu15_temp = Makeint(ram(1) , Ram(2))
  Pu15_temp = Pu15_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 12
    Pu15_temp = 0
  End If
')


 ' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu21_temp = 0
  1wverify Rom_15(1)                                             ' Den gewünschten Sensor auswählen
     If err = 1 then
   1wire_fehler = 15
   1wire_fehlertext = "Fehler PU21 "
   Else

  1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu21_temp = Makeint(ram(1) , Ram(2))
  Pu21_temp = Pu21_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 15
    1wire_fehlertext = "Fehler PU21 "
    Pu21_temp = 0
  End If
  End if

 ' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu22_temp = 0
  1wverify Rom_16(1)                                             ' Den gewünschten Sensor auswählen
     If err = 1 then
   1wire_fehler = 16
   1wire_fehlertext = "Fehler PU22 "
   Else

  1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu22_temp = Makeint(ram(1) , Ram(2))
  Pu22_temp = Pu22_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 16
    1wire_fehlertext = "Fehler PU22 "
    Pu22_temp = 0
  End If
  End if

 ' -----------------------------------------------------------------------------
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu23_temp = 0
  1wverify Rom_17(1)                                             ' Den gewünschten Sensor auswählen
     If err = 1 then
   1wire_fehler = 17
   1wire_fehlertext = "Fehler PU23 "
   Else

  1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu23_temp = Makeint(ram(1) , Ram(2))
  Pu23_temp = Pu23_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 17
    1wire_fehlertext = "Fehler PU23 "
    Pu23_temp = 0
  End If
  End if

 ' -----------------------------------------------------------------------------
Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu24_temp = 0
  1wverify Rom_18(1)                                             ' Den gewünschten Sensor auswählen
     If err = 1 then
   1wire_fehler = 18
   1wire_fehlertext = "Fehler PU24 "
   Else

  1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu24_temp = Makeint(ram(1) , Ram(2))
  Pu24_temp = Pu24_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 18
    1wire_fehlertext = "Fehler PU24 "
    Pu24_temp = 0
  End If
  End if

 ' -----------------------------------------------------------------------------
 '(
 Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Pu25_temp = 0
  1wverify Rom_19(1)                                             ' Den gewünschten Sensor auswählen
1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Pu25_temp = Makeint(ram(1) , Ram(2))
  Pu25_temp = Pu25_temp / 2                                      ' AusLesewert °C berechnen

  Else
    1wire_fehler = 19
    Pu25_temp = 0
  End If

')



 ' -----------------------------------------------------------------------------
Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Aussen_temp = 0
  1wverify Rom_13(1)                                             ' Den gewünschten Sensor auswählen
     If err = 1 then
   1wire_fehler = 13
   1wire_fehlertext = "Fehler AF   "
   Else

  1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Aussen_temp = Makeint(ram(1) , Ram(2))
  Aussen_temp = Aussen_temp / 2                                  ' AusLesewert °C berechnen

  Else
    1wire_fehler = 13
    1wire_fehlertext = "Fehler AF "
    Aussen_temp = 0
  End If
  End if

 ' -----------------------------------------------------------------------------
'(
Ram(1) = 255 : Ram(2) = 255 : Ram(9) = 255 : Oel_temp = 0
  1wverify Rom_14(1)                                             ' Den gewünschten Sensor auswählen
1wwrite Read_ram                                                 ' Kommando READ SCRATCHPAD
 Ram(1) = 1wread(9)
 If Ram(9) = Crc8(ram(1) , 8) Then
  Oel_temp = Makeint(ram(1) , Ram(2))
  Oel_temp = Oel_temp / 2                                        ' AusLesewert °C berechnen

  Else
    1wire_fehler = 14
    Oel_temp = 0
  End If
')

 ' -----------------------------------------------------------------------------



 ' -----------------------------------------------------------------------------


' ======================= Relaikarte Output write 8xIO =========================
'===============================================================================

1wverify Rom_121(1)                                              ' Rom_1 represents the DS2408 ROM address
If Err = 1 Then
   1wire_fehler = 121
   1wire_fehlertext = "Fehler H-Rel"
   Else

   1wwrite &HCC                                                  ' write Conditional Search Register
   1wwrite &H8D                                                  ' Adresse 008D
   1wwrite &H00
   1wwrite &H04                                                  ' ROS = 1   (Sollte immer mitgeschrieben werden, da bei Stromausfall bit verloren geht)

   1wreset
   1wverify Rom_121(1)
   If Err = 1 Then
      1wire_fehler = 121
      1wire_fehlertext = "Fehler H-Rel"
      Else

      Bytetemp = Relais_byte
      1wwrite &H5A                                               ' Pio_access_write
      1wwrite Bytetemp                                           '8_out                            ' Ausgangsbyte senden
      Toggle Bytetemp
      1wwrite Bytetemp                                           ' Invertiertes Byte zur Bestätigung senden
      1wreset
   End If
End If


'===============================================================================
' ================== DCF77 Pin-Status Reading 8xIO ==========================
 1wreset
 1wverify Rom_122(1)                                             ' Den gewünschten Sensor auswählen
  If Err = 1 Then
    1wire_fehler = 122
    1wire_fehlertext = "Fehler DCF  "

    Else
    1wwrite &HF5                                                 ' Pio Access Read
    Dcf_byte_in = 1wread(1)
    1wreset
 End If

' ======================= DCF77 Output write 8xIO =========================



Bytetemp = Dcf_byte_in
Bytetemp.0 = 1                                                   ' Achtung Eingangsbits müssen 1 sein
Bytetemp.1 = 1                                                   ' Achtung Eingangsbits müssen 1 sein
Bytetemp.2 = Inv_tv_abschalten
Bytetemp.3 = Inv_lan_abschalten



1wverify Rom_122(1)                                              ' Rom_1 represents the DS2408 ROM address
If Err = 1 Then
   1wire_fehler = 122
   1wire_fehlertext = "Fehler DCF  "
   Else

   1wwrite &HCC                                                  ' write Conditional Search Register
   1wwrite &H8D                                                  ' Adresse 008D
   1wwrite &H00
   1wwrite &H04                                                  ' ROS = 1   (Sollte immer mitgeschrieben werden, da bei Stromausfall bit verloren geht)

   1wreset
   1wverify Rom_122(1)
   If Err = 1 Then
      1wire_fehler = 122
      1wire_fehlertext = "Fehler DCF  "
      Else

'      Bytetemp = Bytetemp
      1wwrite &H5A                                               ' Pio_access_write
      1wwrite Bytetemp                                           '8_out                            ' Ausgangsbyte senden
      Toggle Bytetemp
      1wwrite Bytetemp                                           ' Invertiertes Byte zur Bestätigung senden
      1wreset
   End If
End If


'===============================================================================






'-------------------------------------------------------------------------------
' ---------------------  Bus wieder freigeben  ------------------------------
Bus_freigeben:

Bus_abfragezaehler = Bus_abfragezeit

Portb.1 = 1
Config Pinb.1 = Input
1wire_freigabe_merker = 1
Lcdat 7 , 96 , " "

1wire_lib_ende:
' -----------------------------------------------------------------------------


'*********************************************************************************************************************************
'*********************** Schaltlogik *********************************************************************************************
'*********************************************************************************************************************************

'(
Verwendete Sensoren:
--------------------
Holzv_temp
Holzr_temp

Pu11_temp
Pu12_temp (Hot Bekämpfung)
Pu13_temp (rote Lampe)

Aussen_temp

Boi1_temp
Boi2_temp

')

Inv_rote_lampe = 1




' ============================ Holzbetrieb =====================================

Bytetemp = Holzbetriebswert
If Holzv_temp >= Bytetemp Then                                   ' zB.60 °C Holzbetrieb => Ein
Holzbetrieb = 1                                                  '
End If

Bytetemp = Bytetemp - 2
If Holzv_temp <= Bytetemp Then                                   ' zB.58 °C Holzbetrieb => Aus
Holzbetrieb = 0
End If

' ---------------------------- M3-Holzkesselpumpe ---------------------------------

If M3_modus = 0 Then M3_inv_holzkesselpumpe = 1                  ' Modus AUS
If M3_modus = 1 Then M3_inv_holzkesselpumpe = 0                  ' Modus EIN
If M3_modus = 2 Then                                             ' Modus AUTO                    ' Pumpe nur an, wenn Holzofen in Betrieb



   If Hot_bekaempfung = 1 Then                                   ' Wenn Heot-Abschaltung, dann Holzofenpumpe an zur Abkühlung
      M3_inv_holzkesselpumpe = 0
      Else



      If Holzbetrieb = 1 Then
         Temp1 = Holzv_temp : Temp1 = Temp1 - 10                 ' Pumpe an, wenn Differenztemperatur erreicht Pumpe an = 0
         If Temp1 >= Holzr_temp Then
            M3_inv_holzkesselpumpe = 0                           '>10°C    <5°C
         End If

         Temp1 = Holzv_temp : Temp1 = Temp1 - 5                  ' Pumpe aus, wenn Differenztemperatur zu klein Pumpe aus = 1
         If Temp1 <= Holzr_temp Then
            M3_inv_holzkesselpumpe = 1
         End If

      Else
      M3_inv_holzkesselpumpe = 1                                 ' Ohne Betrieb keine Pumpe
      End If
   End If
End If
' ------------------------------------------------------------------------------

' ============================ Pufferbetrieb ===================================

Bytetemp = Pufferbetriebswert
If Pu11_temp >= Bytetemp Then                                    ' zB.55 °C Pufferbetrieb => Ein
Bytetemp2 = 1
End If

Bytetemp = Bytetemp - 5
If Pu11_temp <= Bytetemp Then                                    ' zB.50 °C Pufferbetrieb => Aus
Bytetemp2 = 0
End If


If Bytetemp2 = 1 And Hk_zeit_abschaltung = 0 Then                ' Pufferbetrieb verhindern, wenn Zeitabschaltung
Pufferbetrieb = 1
Else
Pufferbetrieb = 0
End If


' ============================ Ölbetrieb =======================================


If Pufferbetrieb = 0 And Holzbetrieb = 0 And Auto_oel_modus = 1 Then       ' Oelbetrieb
Oelbetrieb = 1
Inv_brennerschleife = 0
End If
If Pufferbetrieb = 1 Or Holzbetrieb = 1 Or Auto_oel_modus = 0 Then
Oelbetrieb = 0
Inv_brennerschleife = 1
End If

' ============================ Heizbetrieb ======================================


If Heizkreis_schalter = 1 And Hk_zeit_abschaltung = 0 Then       '
Heizschalter_und_zeit = 1
Else
Heizschalter_und_zeit = 0
End If


' ============================ Energiequelle_on ================================

If Holzbetrieb = 1 Or Pufferbetrieb = 1 Or Oelbetrieb = 1 Then
Energiequelle_on = 1
Else
Energiequelle_on = 0
End If


' +++++++++++++++++++++++++++ Außentemperatur schaltet ab ++++++++++++++++++++++

Bytetemp = Af_aus
If Aussen_temp >= Bytetemp Then                                  ' Af_aus (zB.18 °C) schaltet Heizkreis ab
Af_hk_off = 1
End If

Bytetemp = Bytetemp - 2
If Aussen_temp <= Bytetemp Then                                  ' Af_aus (zB.16 °C) schaltet Heizkreis wieder ein
Af_hk_off = 0
End If


' ++++++++++++++++++++++++++ Rote Lampe  +++++++++++++++++++++++++++++++++

'(
Bytetemp = Rote_lampe                                            ' Rote Lampe leuchtet, wenn eingestellter Schwellwert erreicht ist
If Pu13_temp >= Rote_lampe Then                                  '  Möglich, wenn Puffer (zB.15°C) >= Boiler ist
Inv_rote_lampe = 0
End If

Bytetemp = Bytetemp - 2
If Bytetemp <= Rote_lampe Then                                   ' Rote Lampe erlischt, wenn eingestellter Schwellwert -2 unterschritten wird
Inv_rote_lampe = 1
End If
')


' ++++++++++++++++++++++++++ Boiler von Puffer +++++++++++++++++++++++++++++++++

Bytetemp = Puffer2boilersoll

Temp1 = Pu11_temp - Bytetemp                                     ' Boiler von Puffer laden (dT) termisch möglich ?
If Temp1 >= Boi1_temp Then                                       '  Möglich, wenn Puffer (zB.15°C) >= Boiler ist
Boiler_von_puffer = 1
End If
Temp1 = Temp1 - 2
If Temp1 <= Boi1_temp Then                                       '  Nicht möglich, wenn Puffer (zB.13°C) >= Boiler ist
Boiler_von_puffer = 0
End If




' ++++++++++++++++++++++++++ Boiler Laden ++++++++++++++++++++++++++++++++++++++

Bytetemp = Boilersollmin
If Boi2_temp < Bytetemp Then                                     ' Boilersollmin (zB.37°C) => Ladebeginn
Boiler_laden = 1
End If

Bytetemp = Boilersollmax
If Boi2_temp >= Bytetemp Then                                    ' Boilersollmax (zB.55°C) => Ladeende
Boiler_laden = 0
End If



' --------------------------  M2 Heizkreispumpe --------------------------------

If M2_modus = 0 Then M2_inv_heizkreispumpe = 1                   ' Modus AUS
If M2_modus = 1 Then M2_inv_heizkreispumpe = 0                   ' Modus EIN
If M2_modus = 2 Then                                             ' Modus AUTO

If Heizschalter_und_zeit = 1 And Af_hk_off = 0 And Energiequelle_on = 1 Then       ' Heizkreis_an=Schalter -> Af_hk_off=Außentemp<18° -> Energiequelle_on
M2_inv_heizkreispumpe = 0
Else
M2_inv_heizkreispumpe = 1
End If
End If

' ----------------------------Y1 Boilervorrang ---------------------------------

If Y1_modus = 0 Then Y1_inv_boilervorrang = 1                    ' Modus AUS
If Y1_modus = 1 Then Y1_inv_boilervorrang = 0                    ' Modus EIN
If Y1_modus = 2 Then                                             ' Modus AUTO

If Holzbetrieb = 1 And Boiler_laden = 1 Then                     '     Boilervorrang nur bei Holzbetrieb
Y1_inv_boilervorrang = 0
Else
Y1_inv_boilervorrang = 1
End If
End If

' ---------------------------  M1 Boiler Ladepumpe -----------------------------

If M1_modus = 0 Then M1_inv_boiler_lp = 1                        ' Modus AUS
If M1_modus = 1 Then M1_inv_boiler_lp = 0                        ' Modus EIN
If M1_modus = 2 Then

If Boiler_laden = 1 And Oelbetrieb = 1 And Holzbetrieb = 0 Then
M1_inv_boiler_lp = 0
Else                                                             '
If Boiler_laden = 1 And Boiler_von_puffer = 1 And Holzbetrieb = 0 Then
M1_inv_boiler_lp = 0
Else                                                             ' Pumpe M1 " Boilerladepumpe bei Öl- + Pufferbetrieb, aber nicht bei Holzbetrieb"
M1_inv_boiler_lp = 1                                             '                                    Achtung Brennerschleife Ölbetrieb muss noch eingeschaltet werden
End If
End If
End If

' ---------------------------Y2 Boilerladung mit Holz oder Puffer --------------

If Y2_modus = 0 Then Y2_inv_boilerbetrieb = 1                    ' Modus AUS
If Y2_modus = 1 Then Y2_inv_boilerbetrieb = 0                    ' Modus EIN
If Y2_modus = 2 Then                                             ' Modus AUTO

If Boiler_laden = 1 And Holzbetrieb = 1 Then                     ' Y2 Boilerladung mit Holz oder Puffer ein
Y2_inv_boilerbetrieb = 0
Else
If Boiler_laden = 1 And Boiler_von_puffer = 1 Then
Y2_inv_boilerbetrieb = 0
Else
Y2_inv_boilerbetrieb = 1
End If
End If
End If

' --------------------------- Y3 Heizkreis mit Holz oder Puffer ----------------

If Holzbetrieb = 1 Or Pufferbetrieb = 1 Then                     ' Y3 Umschaltventil Holzbetrieb oder Pufferbetrieb
Temp1 = 1                                                        ' nur wenn Heizkreis in Betrieb
Else
Temp1 = 0
End If

If Y3_modus = 0 Then Y3_inv_heizkreisbetrieb = 1                 ' Modus AUS
If Y3_modus = 1 Then Y3_inv_heizkreisbetrieb = 0                 ' Modus EIN
If Y3_modus = 2 Then                                             ' Modus AUTO

If Heizschalter_und_zeit = 1 And Af_hk_off = 0 And Temp1 = 1 Then
Y3_inv_heizkreisbetrieb = 0
Else
Y3_inv_heizkreisbetrieb = 1
End If
End If

' --------------------------- Brennerschleife ----------------------------------

 If Holzbetrieb = 1 Or Pufferbetrieb = 1 Then
 Temp1 = 1                                                       ' nur wenn Holzbetrieb oder Pufferbetrieb nicht ist
Else
Temp1 = 0
End If

If Bs_modus = 0 Then Inv_brennerschleife = 1                     ' Modus AUS
If Bs_modus = 1 Then Inv_brennerschleife = 0                     ' Modus EIN
If Bs_modus = 2 Then                                             ' Modus AUTO

If Temp1 = 0 And Auto_oel_modus = 1 Then
Inv_brennerschleife = 0
Else
Inv_brennerschleife = 1
End If
End If

' --------------------------- Hot-Bekämpfung der Solaranlage ----------------------------------
' ------------------------------------------------------------------------------

If Pu12_temp >= 95 Then Hot_bekaempfung = 1
If Pu12_temp <= 92 Then Hot_bekaempfung = 0

' ------------------------------------------------------------------------------
' ------------------------------------------------------------------------------





' ------------------------------------------------------------------------------
' ------------------------------------------------------------------------------
' ------------------------------------------------------------------------------

' -----------------Hier wird die Anzeige bei nicht Betätigung zurück auf Startseite gestellt
' ------------------------------------------------------------------------------

If Anzeigeseite > 0 Then

   If Taster_gedrueckt = 1 Then Anzeige_ruecksprungzeit = 20 : Taster_gedrueckt = 0       ' 20 Sekunden als Rückstellzeit !!!!!!!!!!!!

   If _sec <> _sec_alt Then Anzeige_ruecksprungzeit = Anzeige_ruecksprungzeit - 1 : _sec_alt = _sec


   If Anzeige_ruecksprungzeit = 0 Then
      Cls
      Anzeigeseite = 0
   End If
End If


' --------------  Zeitroutine Busabfrage ---------------------------------------
' ------------------------------------------------------------------------------

If Bus_abfragezaehler > 0 Then
   If _sec <> Bus_sec_alt Then Bus_abfragezaehler = Bus_abfragezaehler - 1 : Bus_sec_alt = _sec
End If
' ------------------------------------------------------------------------------

' ---------------------------  Zeit synchronisieren ----------------------------
' ------------------------------------------------------------------------------
' ( täglich von 22:00-06:00 wird von DCF77 A.0=1 ausgegeben )
If Dcf_zeit_bit0 = 0 And Merker_zeit_synchro = 1 Then

   Time$ = "06:00:00"
   Merker_zeit_synchro = 0
   Zeit_ist_aktuell = 1                                          ' Merker_zeit_synchro = 0 verhindert weitere synchronisation

   If Wochentag = 7 Then
      Wochentag = 1
      Else
      Wochentag = Wochentag + 1
   End If
End If

If Dcf_zeit_bit0 = 1 Then Merker_zeit_synchro = 1                ' Merker_zeit_synchro = 1 wird wieder scharf geschaltet bis zur nächsten synchronisation (A.0= High=>Low)
' ------------------------------------------------------------------------------
' ( Sonntags, von 06:00-07:00 wird von DCF77 A.1=1 ausgegeben )
If Dcf_datum_bit1 = 1 And Merker_datum_synchro = 1 Then

   Wochentag = 7
   Merker_datum_synchro = 0                                      ' Merker_zeit_synchro = 0 verhindert weitere synchronisation
'   Zeit_ist_aktuell = 1

End If

If Dcf_datum_bit1 = 0 Then Merker_datum_synchro = 1              ' Merker_zeit_synchro = 1 wird wieder scharf geschaltet bis zur nächsten synchronisation (A.0= High=>Low)
' ------------------------------------------------------------------------------

' ============================ Tag & Nachtabschaltung des Heizkreises ==========

If Zeit_aus_schalter = 1 Then
Hk_tagabschaltung = 0
Hk_nachtabschaltung = 0
Else





' Montags bis Freitags
If Wochentag >= 1 And Wochentag <= 5 Then                        '                                  §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
   If Menue_tag_off = 1 And Time$ > "09:00:00" And Time$ < "17:00:00" Then       'Montag - Freitag
      Hk_tagabschaltung = 1                                      '                                   Hier wird die Zeit Tagabschaltung eingetragen
      Else                                                       '                                   §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
      Hk_tagabschaltung = 0
   End If
   If Menue_nacht_off = 1 Then                                   '                                  §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
      If Time$ > "05:50:00" And Time$ < "22:15:00" Then          '                Montag - Freitag
         Hk_nachtabschaltung = 0                                 '                                   Hier wird die Zeit Nachtabschaltung eingetragen
      Else                                                       '                                   §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
         Hk_nachtabschaltung = 1
      End If
   Else
   Hk_nachtabschaltung = 0
   End If
End If
' ------------------------------------------------------------------------------
' Samstags
If Wochentag = 6 Then                                            '                                  §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
   If Menue_tag_off = 1 And Time$ > "09:00:00" And Time$ < "17:00:00" Then       'Montag - Freitag
      Hk_tagabschaltung = 1                                      '                                   Hier wird die Zeit Tagabschaltung eingetragen
      Else                                                       '                                   §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
      Hk_tagabschaltung = 0
   End If
   If Menue_nacht_off = 1 Then                                   '                                  §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
      If Time$ > "04:45:00" And Time$ < "22:15:00" Then          '                Montag - Freitag
         Hk_nachtabschaltung = 0                                 '                                   Hier wird die Zeit Nachtabschaltung eingetragen
      Else                                                       '                                   §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
         Hk_nachtabschaltung = 1
      End If
   Else
   Hk_nachtabschaltung = 0
   End If
End If
' ------------------------------------------------------------------------------
' Sonntags
If Wochentag = 7 Then                                            '                                  §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
   If Menue_tag_off = 1 And Time$ > "09:00:00" And Time$ < "17:00:00" Then       'Montag - Freitag
      Hk_tagabschaltung = 1                                      '                                   Hier wird die Zeit Tagabschaltung eingetragen
      Else                                                       '                                   §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
      Hk_tagabschaltung = 0
   End If
   If Menue_nacht_off = 1 Then                                   '                                  §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
      If Time$ > "06:30:00" And Time$ < "22:15:00" Then          '                Montag - Freitag
         Hk_nachtabschaltung = 0                                 '                                   Hier wird die Zeit Nachtabschaltung eingetragen
      Else                                                       '                                   §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
         Hk_nachtabschaltung = 1
      End If
   Else
   Hk_nachtabschaltung = 0
   End If
End If

End If
' ------------------------------------------------------------------------------

If Hk_tagabschaltung = 1 Or Hk_nachtabschaltung = 1 Then
Hk_zeit_abschaltung = 1
Else
Hk_zeit_abschaltung = 0
End If


' ---------------------------  TV Abschaltung ----------------------------------
' ------------------------------------------------------------------------------

If Tv_modus = 0 Then Inv_tv_abschalten = 0                       ' Modus AUS   0= PNP-schaltet und Relais mit öffner angezogen
If Tv_modus = 1 Then Inv_tv_abschalten = 1                       ' Modus EIN   1= PNP-OFF und Relais mit öffner nicht angezogen
If Tv_modus = 2 Then                                             ' Modus AUTO

   If Zeit_aus_schalter = 1 Then
   Inv_tv_abschalten = 1
   Else
      If Time$ > "06:00:00" And Time$ < "22:30:00" Then          '                   §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
         Inv_tv_abschalten = 1                                   '                                   Hier wird die TV Zeit eingetragen
         Else                                                    '                                  §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
         Inv_tv_abschalten = 0
      End If
   End If
End If
' ---------------------------  LAN Abschaltung ----------------------------------
' ------------------------------------------------------------------------------

If Lan_modus = 0 Then Inv_lan_abschalten = 0                     ' Modus AUS   0= PNP-schaltet und Relais mit öffner angezogen
If Lan_modus = 1 Then Inv_lan_abschalten = 1                     ' Modus EIN   1= PNP-OFF und Relais mit öffner nicht angezogen
If Lan_modus = 2 Then                                            ' Modus AUTO


   If Zeit_aus_schalter = 1 Then
   Inv_lan_abschalten = 1
   Else

       If Time$ > "06:00:00" And Time$ < "22:30:00" Then         '                   §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
          Inv_lan_abschalten = 1                                 '                                   Hier Wird Die Tv Zeit Eingetragen
          Else                                                   '                                  §§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§
          Inv_lan_abschalten = 0
       End If
   End If
End If

' ------------------------------------------------------------------------------











'*********************************************************************************************************************************
' ********************** Anzeige ausgeben ****************************************************************************************
'*********************************************************************************************************************************

' Zeit anzeigen
If 1wire_fehlertext = "            " then
   Lcdat 7 , 1 , Time$ ; "    "
   else
   Lcdat 7 , 1 , 1wire_fehlertext
End if

Lcdat 7 , 104 , Anzeigeseite

'Ausgänge anzeigen

If Solar_modus = 0 Then Showpic 0 , 56 , Solar_aus               ' Symbol Solaranlage Außer Betrieb
If Solar_modus = 2 Then                                          ' Nur Boiler laden
If M4_inv_solar_pumpe = 0 And Y4_inv_puffer_laden = 1 Then Showpic 0 , 56 , Solar_nurboiler_laden       ' Symbol Solar nur Boiler laden
If M4_inv_solar_pumpe = 1 And Y4_inv_puffer_laden = 1 Then Showpic 0 , 56 , Solar_nurboiler       ' Symbol Solar nur Boiler
End If

If Solar_modus = 1 Then
If M4_inv_solar_pumpe = 0 And Y4_inv_puffer_laden = 1 Then Showpic 0 , 56 , Solar_boiler_laden       ' Symbol Solar Boiler laden
If M4_inv_solar_pumpe = 0 And Y4_inv_puffer_laden = 0 Then Showpic 0 , 56 , Solar_puffer_laden       ' Symbol Solar Puffer laden
If M4_inv_solar_pumpe = 1 And Y4_inv_puffer_laden = 1 Then Showpic 0 , 56 , Solar_boiler       ' Symbol Solar Boiler
If M4_inv_solar_pumpe = 1 And Y4_inv_puffer_laden = 0 Then Showpic 0 , 56 , Solar_puffer       ' Symbol Solar Puffer
End If

If Solarbyte.4 = 1 Then Showpic 8 , 56 , Service                 ' Symbol Service
If Solarbyte.4 = 0 Then Showpic 8 , 56 , Leer

'(
If Hot_bekaempfung = 1 Then Lcdat 16 , 56 , "H"                  '  Anzeige Piktogramm muss noch erstellt werden !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
If Hot_bekaempfung = 0 Then Lcdat 16 , 56 , " "                  ' !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
')



If M2_inv_heizkreispumpe = 0 Then Showpic 40 , 56 , Heizkreis    ' Symbol Heizkörper für Heizkreispumpe an
If Hk_tagabschaltung = 1 Then Showpic 40 , 56 , Tagabschaltung   ' Symbol Tagabsenkung an
If Hk_nachtabschaltung = 1 Then Showpic 40 , 56 , Nachtabschaltung       ' Symbol Nachtabsenkung an
If M2_inv_heizkreispumpe = 1 And Hk_zeit_abschaltung = 0 Then Showpic 40 , 56 , Leer


If M1_inv_boiler_lp = 0 Then Showpic 48 , 56 , Brauchwasserladung       ' Symbol Wasserhahn für Boiler Ladepumpe an  '(Chr 203=Hahn ohne Tropfen)
If M1_inv_boiler_lp = 1 Then Showpic 48 , 56 , Leer

If Aussen_temp >= 18 Then Showpic 56 , 56 , Sonne                ' Symbol Sonne für Außentemperatur >18°C an
If Aussen_temp < 18 Then Showpic 56 , 56 , Leer



' Fehler am 1-Wire Bus anzeigen
If 1wire_fehler = 255 Then
   Showpic 64 , 56 , Service
   Lcdat 8 , 72 , "Bus"
   Else
   If 1wire_fehler > 99 Then
      Showpic 64 , 56 , Service
      Lcdat 8 , 72 , 1wire_fehler
      Else
      If 1wire_fehler > 9 Then
         Showpic 64 , 56 , Service
         Lcdat 8 , 72 , 1wire_fehler
         Lcdat 8 , 88 , " "
         Else
         If 1wire_fehler > 0 Then
             Showpic 64 , 56 , Service
             Lcdat 8 , 72 , 1wire_fehler
             Lcdat 8 , 88 , "  "
             Else
             Showpic 64 , 56 , Leer
             Lcdat 8 , 72 , "   "
         End If
      End If
   End If
End If

1wire_fehler = 0                                                 ' Fehler nach Anzeige wieder zturücksetzen

'-------------------------------------------------------------------------------
If Merker_taster_enter = 1 Then Cls
If Merker_taster_zurueck = 1 Then Cls
If Merker_taster_minus = 1 Then Cls
If Merker_taster_plus = 1 Then Cls

Merker_taster_enter = 0
Merker_taster_zurueck = 0
Merker_taster_minus = 0
Merker_taster_plus = 0
Taster_gedrueckt = 0

Debounce Taster_enter , 0 , T_enter
Debounce Taster_zurueck , 0 , T_zurueck
Debounce Taster_minus , 0 , T_minus
Debounce Taster_plus , 0 , T_plus
Goto Taster_ende
T_enter:
Merker_taster_enter = 1 : Taster_gedrueckt = 1
Goto Taster_ende
T_zurueck:
Merker_taster_zurueck = 1 : Taster_gedrueckt = 1
Goto Taster_ende
T_minus:
Merker_taster_minus = 1 : Taster_gedrueckt = 1
Goto Taster_ende
T_plus:
Merker_taster_plus = 1 : Taster_gedrueckt = 1
Taster_ende:
'-------------------------------------------------------------------------------


Select Case Anzeigeseite
Case 0 : Gosub Blatt_0
Case 1 : Gosub Blatt_1
Case 2 : Gosub Blatt_2
Case 3 : Gosub Blatt_3
Case 4 : Gosub Blatt_4
Case 5 : Gosub Blatt_5

Case 11 : Gosub Blatt_11
Case 12 : Gosub Blatt_12
Case 13 : Gosub Blatt_13
Case 14 : Gosub Blatt_14
Case 15 : Gosub Blatt_15


Case 111 : Gosub Blatt_111
Case 121 : Gosub Blatt_121
Case 131 : Gosub Blatt_131
Case 141 : Gosub Blatt_141
Case 151 : Gosub Blatt_151

Case 21 : Gosub Blatt_21
Case 22 : Gosub Blatt_22
Case 23 : Gosub Blatt_23
Case 24 : Gosub Blatt_24
Case 25 : Gosub Blatt_25
Case 26 : Gosub Blatt_26

Case 31 : Gosub Blatt_31
Case 32 : Gosub Blatt_32

Case 311 : Gosub Blatt_311
Case 321 : Gosub Blatt_321

Case 41 : Gosub Blatt_41
Case 42 : Gosub Blatt_42
Case 43 : Gosub Blatt_43
Case 44 : Gosub Blatt_44
Case 45 : Gosub Blatt_45

Case 51 : Gosub Blatt_51
Case 52 : Gosub Blatt_52
Case 53 : Gosub Blatt_53
Case 54 : Gosub Blatt_54
Case 55 : Gosub Blatt_55

Case 511 : Gosub Blatt_511
Case 512 : Gosub Blatt_512
Case 513 : Gosub Blatt_513
Case 514 : Gosub Blatt_514

Case 521 : Gosub Blatt_521

Case 531 : Gosub Blatt_531
Case 532 : Gosub Blatt_532
Case 533 : Gosub Blatt_533
Case 534 : Gosub Blatt_534

Case 541 : Gosub Blatt_541
Case 542 : Gosub Blatt_542
Case 543 : Gosub Blatt_543
Case 544 : Gosub Blatt_544
Case 545 : Gosub Blatt_545
Case 546 : Gosub Blatt_546
Case 547 : Gosub Blatt_547
Case 548 : Gosub Blatt_548

Case 551 : Gosub Blatt_551
Case 552 : Gosub Blatt_552

End Select

Goto Blaetter_ende

'-------------------------------------------------------------------------------

Blatt_0:                                                         ' 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0

Showpic 25 , 1 , Pufferspeicher                                  ' Pufferspeicher und Werte ausgeben
Lcdat 1 , 1 , Pu21_temp ; Chr(248)                               ' Ausgabe an Position  Zeile,Pos,
Lcdat 2 , 1 , Pu22_temp ; Chr(248)                               ' Ausgabe an Position  Zeile,Pos,
Lcdat 3 , 1 , Pu23_temp ; Chr(248)                               ' Ausgabe an Position  Zeile,Pos,
Lcdat 4 , 1 , Pu24_temp ; Chr(248)                               ' Ausgabe an Position  Zeile,Pos,

Showpic 78 , 1 , Wasserspeicher                                  ' Anzeige des Bildes an Pos X,Y
Lcdat 1 , 104 , Boi1_temp ; Chr(248)                             ' Ausgabe an Position  Zeile,Pos,
Lcdat 2 , 104 , Boi2_temp ; Chr(248)                             ' Ausgabe an Position  Zeile,Pos,

Lcdat 6 , 96 , "AF" ; Aussen_temp ; " "


'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Lcdat 6 , 1 , " "                                                ' Frei für Testzwecke

'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Lcdat 8 , 120 , Chr(236)
If Merker_taster_enter = 1 Then Anzeigeseite = 1                 ' Mit Enter Strung zu Seite Menue


Return
'-------------------------------------------------------------------------------

Blatt_1:                                                         ' 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1

Lcdat 1 , 1 , "MENUE"
Lcdat 2 , 8 , "Temperaturwerte" , 1
Lcdat 3 , 8 , "Betriebsarten"
Lcdat 4 , 8 , "Zustaende"
Lcdat 5 , 8 , "Parameter"
Lcdat 6 , 8 , "System Setup"


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 11
If Merker_taster_zurueck = 1 Then Anzeigeseite = 0
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = 2

Return
'-------------------------------------------------------------------------------
Blatt_2:                                                         ' 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2

Lcdat 1 , 1 , "MENUE"
Lcdat 2 , 8 , "Temperaturwerte"
Lcdat 3 , 8 , "Betriebsarten" , 1
Lcdat 4 , 8 , "Zustaende"
Lcdat 5 , 8 , "Parameter"
Lcdat 6 , 8 , "System Setup"


Lcdat 8 , 96 , Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 21
If Merker_taster_zurueck = 1 Then Anzeigeseite = 0
If Merker_taster_minus = 1 Then Anzeigeseite = 1
If Merker_taster_plus = 1 Then Anzeigeseite = 3

Return
'-------------------------------------------------------------------------------
Blatt_3:                                                         ' 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3

Lcdat 1 , 1 , "MENUE"
Lcdat 2 , 8 , "Temperaturwerte"
Lcdat 3 , 8 , "Betriebsarten"
Lcdat 4 , 8 , "Zustaende" , 1
Lcdat 5 , 8 , "Parameter"
Lcdat 6 , 8 , "System Setup"


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 31
If Merker_taster_zurueck = 1 Then Anzeigeseite = 0
If Merker_taster_minus = 1 Then Anzeigeseite = 2
If Merker_taster_plus = 1 Then Anzeigeseite = 4

Return
'-------------------------------------------------------------------------------
Blatt_4:                                                         ' 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4

Lcdat 1 , 1 , "MENUE"
Lcdat 2 , 8 , "Temperaturwerte"
Lcdat 3 , 8 , "Betriebsarten"
Lcdat 4 , 8 , "Zustaende"
Lcdat 5 , 8 , "Parameter" , 1
Lcdat 6 , 8 , "System Setup"


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 41
If Merker_taster_zurueck = 1 Then Anzeigeseite = 0
If Merker_taster_minus = 1 Then Anzeigeseite = 3
If Merker_taster_plus = 1 Then Anzeigeseite = 5

Return
'-------------------------------------------------------------------------------
Blatt_5:                                                         ' 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5

Lcdat 1 , 1 , "MENUE"
Lcdat 2 , 8 , "Temperaturwerte"
Lcdat 3 , 8 , "Betriebsarten"
Lcdat 4 , 8 , "Zustaende"
Lcdat 5 , 8 , "Parameter"
Lcdat 6 , 8 , "System Setup" , 1


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236)
If Merker_taster_enter = 1 Then Anzeigeseite = 51
If Merker_taster_zurueck = 1 Then Anzeigeseite = 0
If Merker_taster_minus = 1 Then Anzeigeseite = 4
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------
Blatt_11:                                                        ' 11 11 11 11 11 11 11 11 11 11 11

Lcdat 1 , 1 , "TEMPERATURWERTE"
Lcdat 2 , 8 , "Puffer" , 1
Lcdat 3 , 8 , "Solar"
Lcdat 4 , 8 , "Heizkreis  +AF"
Lcdat 5 , 8 , "Holzkessel +Oel"
Lcdat 6 , 8 , " "


Lcdat 8 , 96 , Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 111
If Merker_taster_zurueck = 1 Then Anzeigeseite = 1
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = 12

Return
'-------------------------------------------------------------------------------
Blatt_12:                                                        ' 12 12 12 12 12 12 12 12 12 12 12

Lcdat 1 , 1 , "TEMPERATURWERTE"
Lcdat 2 , 8 , "Puffer"
Lcdat 3 , 8 , "Solar" , 1
Lcdat 4 , 8 , "Heizkreis  +AF"
Lcdat 5 , 8 , "Holzkessel +Oel"
Lcdat 6 , 8 , " "


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 121
If Merker_taster_zurueck = 1 Then Anzeigeseite = 2
If Merker_taster_minus = 1 Then Anzeigeseite = 11
If Merker_taster_plus = 1 Then Anzeigeseite = 13

Return
'-------------------------------------------------------------------------------
Blatt_13:                                                        ' 13 13 13 13 13 13 13 13 13 13 13

Lcdat 1 , 1 , "TEMPERATURWERTE"
Lcdat 2 , 8 , "Puffer"
Lcdat 3 , 8 , "Solar"
Lcdat 4 , 8 , "Heizkreis  +AF" , 1
Lcdat 5 , 8 , "Holzkessel +Oel"
Lcdat 6 , 8 , " "


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 131
If Merker_taster_zurueck = 1 Then Anzeigeseite = 3
If Merker_taster_minus = 1 Then Anzeigeseite = 12
If Merker_taster_plus = 1 Then Anzeigeseite = 14

Return
'-------------------------------------------------------------------------------
Blatt_14:                                                        ' 14 14 14 14 14 14 14 14 14 14 14

Lcdat 1 , 1 , "TEMPERATURWERTE"
Lcdat 2 , 8 , "Puffer"
Lcdat 3 , 8 , "Solar"
Lcdat 4 , 8 , "Heizkreis  +AF"
Lcdat 5 , 8 , "Holzkessel +Oel" , 1
Lcdat 6 , 8 , " "


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 141
If Merker_taster_zurueck = 1 Then Anzeigeseite = 4
If Merker_taster_minus = 1 Then Anzeigeseite = 13
If Merker_taster_plus = 1 Then Anzeigeseite = 15

Return
'-------------------------------------------------------------------------------
Blatt_15:                                                        ' 15 15 15 15 15 15 15 15 15 15 15

Lcdat 1 , 1 , "TEMPERATURWERTE"
Lcdat 2 , 8 , "Puffer"
Lcdat 3 , 8 , "Solar"
Lcdat 4 , 8 , "Heizkreis  +AF"
Lcdat 5 , 8 , "Holzkessel +Oel"
Lcdat 6 , 8 , " " , 1


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236)
If Merker_taster_enter = 1 Then Anzeigeseite = 151
If Merker_taster_zurueck = 1 Then Anzeigeseite = 5
If Merker_taster_minus = 1 Then Anzeigeseite = 14
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_111:                                                       ' 111 111 111 111 111 111 111 111

Lcdat 1 , 1 , "Pu3   Pu2   Pu1"
Lcdat 2 , 1 , Pu31_temp ; Chr(248)
Lcdat 3 , 1 , Pu32_temp ; Chr(248)
Lcdat 4 , 1 , Pu33_temp ; Chr(248)

Lcdat 2 , 48 , Pu21_temp ; Chr(248)
Lcdat 3 , 48 , Pu22_temp ; Chr(248)
Lcdat 4 , 48 , Pu23_temp ; Chr(248)
Lcdat 5 , 48 , Pu24_temp ; Chr(248)
Lcdat 6 , 48 , Pu25_temp ; Chr(248)

Lcdat 2 , 96 , Pu11_temp ; Chr(248)
Lcdat 3 , 96 , Pu12_temp ; Chr(248)
Lcdat 4 , 96 , Pu13_temp ; Chr(248)
Lcdat 5 , 96 , Pu14_temp ; Chr(248)
Lcdat 6 , 96 , Pu15_temp ; Chr(248)


Lcdat 8 , 96 , Chr(237)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 11
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_121:                                                       ' 121 121 121 121 121 121 121 121

Lcdat 1 , 1 , "SOLARTEMPERATUR"
Lcdat 2 , 1 , "P1=" ; Solar_panel_1 ; Chr(248)
Lcdat 3 , 1 , "P2=" ; Solar_panel_2 ; Chr(248)
Lcdat 4 , 1 , "P3=" ; Solar_panel_3 ; Chr(248)

Lcdat 2 , 64 , "P4=" ; Solar_panel_4 ; Chr(248)
Lcdat 3 , 64 , "P5=" ; Solar_panel_5 ; Chr(248)
Lcdat 4 , 64 , "P6=" ; Solar_panel_6 ; Chr(248)

Lcdat 5 , 1 , "Pu13=" ; Pu13_temp ; Chr(248)
Lcdat 5 , 64 , "Boi2=" ; Boi2_temp ; Chr(248)


Lcdat 8 , 96 , Chr(237)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 12
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_131:                                                       ' 131 131 131 131 131 131 131 131

Lcdat 1 , 1 , "HEIZKREISTEMP."

Lcdat 3 , 1 , "Au" ; Chr(225) ; "entemp.   " ; Aussen_temp ; Chr(248)
' Lcdat 4 , 1 , "Hk-Soll      " ; Hkv_soll ; Chr(248)
Lcdat 5 , 1 , "Hk-Vorlauf   " ; Hkv_temp ; Chr(248)
Lcdat 6 , 1 , "Hk-Ruecklauf " ; Hkr_temp ; Chr(248)

Lcdat 8 , 96 , Chr(237)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 13
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_141:                                                       ' 141 141 141 141 141 141 141 141

Lcdat 1 , 1 , "HOLZKESSEL + OEL"

Lcdat 3 , 1 , "Holzk Vorl.  " ; Holzv_temp ; Chr(248)
Lcdat 4 , 1 , "Holzk Rueckl " ; Holzr_temp ; Chr(248)
Lcdat 5 , 1 , "Oelkessel    " ; Oel_temp ; Chr(248)

Lcdat 8 , 96 , Chr(237)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 14
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------
Blatt_151:                                                       ' 151 151 151 151 151 151 151 151
Lcdat 1 , 1 , "FREI"


Lcdat 8 , 96 , Chr(237)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 15
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_21:                                                        ' 21 21 21 21 21 21 21 21 21 21 21
Lcdat 1 , 1 , "BETRIEBSARTEN"

If Heizkreis_schalter = 1 Then Lcdat 2 , 1 , "Heizkreis = Ein " , 1
If Heizkreis_schalter = 0 Then Lcdat 2 , 1 , "Heizkreis = Aus " , 1
If Auto_oel_modus = 1 Then Lcdat 3 , 1 , "Oelofen = bereit"
If Auto_oel_modus = 0 Then Lcdat 3 , 1 , "Oelofen   = Aus "
If Menue_nacht_off = 1 Then Lcdat 4 , 1 , "Nacht_off = Ein "
If Menue_nacht_off = 0 Then Lcdat 4 , 1 , "Nacht_off = Aus "
If Menue_tag_off = 1 Then Lcdat 5 , 1 , "Tag_off   = Ein "
If Menue_tag_off = 0 Then Lcdat 5 , 1 , "Tag_off   = Aus "

If Solar_modus = 0 Then Lcdat 6 , 1 , "Solar     = Aus "
If Solar_modus = 1 Then Lcdat 6 , 1 , "Solar     = Ein "
If Solar_modus = 2 Then Lcdat 6 , 1 , "Solar = nur Boil"
If Solar_modus > 2 Then Lcdat 6 , 1 , "Solar = " ; Solar_modus

Lcdat 8 , 96 , Chr(237) ; Chr(236)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite + 1
If Merker_taster_zurueck = 1 Then Anzeigeseite = 2
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_22:                                                        ' 22 22 22 22 22 22 22 22 22 22 22
Lcdat 1 , 1 , "BETRIEBSARTEN"

If Heizkreis_schalter = 1 Then Lcdat 2 , 1 , "Heizkreis = Ein "
If Heizkreis_schalter = 0 Then Lcdat 2 , 1 , "Heizkreis = Aus "
If Auto_oel_modus = 1 Then Lcdat 3 , 1 , "Oelofen = bereit" , 1
If Auto_oel_modus = 0 Then Lcdat 3 , 1 , "Oelofen   = Aus " , 1
If Menue_nacht_off = 1 Then Lcdat 4 , 1 , "Nacht_off = Ein "
If Menue_nacht_off = 0 Then Lcdat 4 , 1 , "Nacht_off = Aus "
If Menue_tag_off = 1 Then Lcdat 5 , 1 , "Tag_off   = Ein "
If Menue_tag_off = 0 Then Lcdat 5 , 1 , "Tag_off   = Aus "

If Solar_modus = 0 Then Lcdat 6 , 1 , "Solar     = Aus "
If Solar_modus = 1 Then Lcdat 6 , 1 , "Solar     = Ein "
If Solar_modus = 2 Then Lcdat 6 , 1 , "Solar = nur Boil"
If Solar_modus > 2 Then Lcdat 6 , 1 , "Solar = " ; Solar_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite + 1
If Merker_taster_zurueck = 1 Then Anzeigeseite = 21
If Merker_taster_minus = 1 Then Auto_oel_modus = 0 : Eram_auto_oel_modus = Auto_oel_modus
If Merker_taster_plus = 1 Then Auto_oel_modus = 1 : Eram_auto_oel_modus = Auto_oel_modus

Return
'-------------------------------------------------------------------------------

Blatt_23:                                                        ' 23 23 23 23 23 23 23 23 23 23 23
Lcdat 1 , 1 , "BETRIEBSARTEN"

If Heizkreis_schalter = 1 Then Lcdat 2 , 1 , "Heizkreis = Ein "
If Heizkreis_schalter = 0 Then Lcdat 2 , 1 , "Heizkreis = Aus "
If Auto_oel_modus = 1 Then Lcdat 3 , 1 , "Oelofen = bereit"
If Auto_oel_modus = 0 Then Lcdat 3 , 1 , "Oelofen   = Aus "
If Menue_nacht_off = 1 Then Lcdat 4 , 1 , "Nacht_off = Ein " , 1
If Menue_nacht_off = 0 Then Lcdat 4 , 1 , "Nacht_off = Aus " , 1
If Menue_tag_off = 1 Then Lcdat 5 , 1 , "Tag_off   = Ein "
If Menue_tag_off = 0 Then Lcdat 5 , 1 , "Tag_off   = Aus "

If Solar_modus = 0 Then Lcdat 6 , 1 , "Solar     = Aus "
If Solar_modus = 1 Then Lcdat 6 , 1 , "Solar     = Ein "
If Solar_modus = 2 Then Lcdat 6 , 1 , "Solar = nur Boil"
If Solar_modus > 2 Then Lcdat 6 , 1 , "Solar = " ; Solar_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite + 1
If Merker_taster_zurueck = 1 Then Anzeigeseite = 22
If Merker_taster_minus = 1 Then Menue_nacht_off = 0 : Eram_menue_nacht_off = Menue_nacht_off
If Merker_taster_plus = 1 Then Menue_nacht_off = 1 : Eram_menue_nacht_off = Menue_nacht_off

Return
'-------------------------------------------------------------------------------

Blatt_24:                                                        ' 24 24 24 24 24 24 24 24 24 24 24
Lcdat 1 , 1 , "BETRIEBSARTEN"

If Heizkreis_schalter = 1 Then Lcdat 2 , 1 , "Heizkreis = Ein "
If Heizkreis_schalter = 0 Then Lcdat 2 , 1 , "Heizkreis = Aus "
If Auto_oel_modus = 1 Then Lcdat 3 , 1 , "Oelofen = bereit"
If Auto_oel_modus = 0 Then Lcdat 3 , 1 , "Oelofen   = Aus "
If Menue_nacht_off = 1 Then Lcdat 4 , 1 , "Nacht_off = Ein "
If Menue_nacht_off = 0 Then Lcdat 4 , 1 , "Nacht_off = Aus "
If Menue_tag_off = 1 Then Lcdat 5 , 1 , "Tag_off   = Ein " , 1
If Menue_tag_off = 0 Then Lcdat 5 , 1 , "Tag_off   = Aus " , 1

If Solar_modus = 0 Then Lcdat 6 , 1 , "Solar     = Aus "
If Solar_modus = 1 Then Lcdat 6 , 1 , "Solar     = Ein "
If Solar_modus = 2 Then Lcdat 6 , 1 , "Solar = nur Boil"
If Solar_modus > 2 Then Lcdat 6 , 1 , "Solar = " ; Solar_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite + 1
If Merker_taster_zurueck = 1 Then Anzeigeseite = 23
If Merker_taster_minus = 1 Then Menue_tag_off = 0 : Eram_menue_tag_off = Menue_nacht_off
If Merker_taster_plus = 1 Then Menue_tag_off = 1 : Eram_menue_tag_off = Menue_nacht_off

Return
'-------------------------------------------------------------------------------


Blatt_25:                                                        ' 25 25 25 25 25 25 25 25 25 25 25
Lcdat 1 , 1 , "BETRIEBSARTEN"

If Heizkreis_schalter = 1 Then Lcdat 2 , 1 , "Heizkreis = Ein "
If Heizkreis_schalter = 0 Then Lcdat 2 , 1 , "Heizkreis = Aus "
If Auto_oel_modus = 1 Then Lcdat 3 , 1 , "Oelofen = bereit"
If Auto_oel_modus = 0 Then Lcdat 3 , 1 , "Oelofen   = Aus "
If Menue_nacht_off = 1 Then Lcdat 4 , 1 , "Nacht_off = Ein "
If Menue_nacht_off = 0 Then Lcdat 4 , 1 , "Nacht_off = Aus "
If Menue_tag_off = 1 Then Lcdat 5 , 1 , "Tag_off   = Ein "
If Menue_tag_off = 0 Then Lcdat 5 , 1 , "Tag_off   = Aus "

If Solar_modus = 0 Then Lcdat 6 , 1 , "Solar     = Aus " , 1
If Solar_modus = 1 Then Lcdat 6 , 1 , "Solar     = Ein " , 1
If Solar_modus = 2 Then Lcdat 6 , 1 , "Solar = nur Boil" , 1
If Solar_modus > 2 Then Lcdat 6 , 1 , "Solar = " ; Solar_modus , 1


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite + 1
If Merker_taster_zurueck = 1 Then Anzeigeseite = 24
If Merker_taster_minus = 1 Then Solar_modus = Solar_modus - 1 : Eram_solar_modus = Solar_modus
If Merker_taster_plus = 1 Then Solar_modus = Solar_modus + 1 : Eram_solar_modus = Solar_modus

Return
'-------------------------------------------------------------------------------

Blatt_26:                                                        ' 26 26 26 26 26 26 26 26 26 26 26
Lcdat 1 , 1 , "BETRIEBSARTEN"


If Mischer_in_betrieb = 0 Then Lcdat 3 , 1 , "Mischerst. = Aus" , 1
If Mischer_in_betrieb = 1 Then Lcdat 3 , 1 , "Mischerst. = Ein" , 1



Lcdat 8 , 96 , "-" ; Chr(237) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 25
If Merker_taster_minus = 1 Then Mischer_in_betrieb = 0 : Eram_mischer_in_betrieb = Mischer_in_betrieb
If Merker_taster_plus = 1 Then Mischer_in_betrieb = 1 : Eram_mischer_in_betrieb = Mischer_in_betrieb

Return
'-------------------------------------------------------------------------------





Blatt_31:                                                        ' 31 31 31 31 31 31 31 31 31 31 31
Lcdat 1 , 1 , "ZUSTAENDE"

Lcdat 3 , 8 , "Betriebsphasen" , 1
Lcdat 4 , 8 , "Ausgaenge"

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 311
If Merker_taster_zurueck = 1 Then Anzeigeseite = 3
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = 32

Return
'-------------------------------------------------------------------------------

Blatt_32:                                                        ' 32 32 32 32 32 32 32 32 32 32 32
Lcdat 1 , 1 , "ZUSTAENDE"

Lcdat 3 , 8 , "Betriebsphasen"
Lcdat 4 , 8 , "Ausgaenge" , 1



Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 321
If Merker_taster_zurueck = 1 Then Anzeigeseite = 3
If Merker_taster_minus = 1 Then Anzeigeseite = 31
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_311:                                                       ' 311 311 311 311 311 311 311 311
Lcdat 1 , 1 , "BETRIEBSPHASEN"


If Boiler_von_puffer = 1 Then Lcdat 3 , 1 , "Puffer > Boiler"
If Boiler_von_puffer = 0 Then Lcdat 3 , 1 , "Puffer < Boiler"

If Boiler_laden = 1 Then Lcdat 4 , 1 , "Boiler laden"
If Boiler_laden = 0 Then Lcdat 4 , 1 , "Boiler OK.  "

If Af_hk_off = 1 Then Lcdat 5 , 1 , "Au" ; Chr(225) ; "ent. >18" ; Chr(248)
If Af_hk_off = 0 Then Lcdat 5 , 1 , "Au" ; Chr(225) ; "ent. <18" ; Chr(248)

If Energiequelle_on = 1 Then Lcdat 6 , 1 , "Energie on "
If Energiequelle_on = 0 Then Lcdat 6 , 1 , "Energie off"

Lcdat 8 , 96 , Chr(237)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 31
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_321:                                                       ' 321 321 321 321 321 321 321 321
Lcdat 1 , 1 , "AUSGAENGE"

If M1_inv_boiler_lp = 0 Then Lcdat 2 , 1 , "M1-BLP1"
If M1_inv_boiler_lp = 1 Then Lcdat 2 , 1 , "M1-BLP0"

If M2_inv_heizkreispumpe = 0 Then Lcdat 3 , 1 , "M2-HK 1"
If M2_inv_heizkreispumpe = 1 Then Lcdat 3 , 1 , "M2-HK 0"

If M3_inv_holzkesselpumpe = 0 Then Lcdat 4 , 1 , "M3-Ho 1"
If M3_inv_holzkesselpumpe = 1 Then Lcdat 4 , 1 , "M3-Ho 0"

If M4_inv_solar_pumpe = 0 Then Lcdat 5 , 1 , "M4-SP 1"
If M4_inv_solar_pumpe = 1 Then Lcdat 5 , 1 , "M4-SP 0"

If Y1_inv_boilervorrang = 0 Then Lcdat 2 , 64 , "Y1-BV 1"
If Y1_inv_boilervorrang = 1 Then Lcdat 2 , 64 , "Y1-BV 0"

If Y2_inv_boilerbetrieb = 0 Then Lcdat 3 , 64 , "Y2-BL 1"
If Y2_inv_boilerbetrieb = 1 Then Lcdat 3 , 64 , "Y2-BL 0"

If Y3_inv_heizkreisbetrieb = 0 Then Lcdat 4 , 64 , "Y3-HK 1"
If Y3_inv_heizkreisbetrieb = 1 Then Lcdat 4 , 64 , "Y3-HK 0"

If Y4_inv_puffer_laden = 0 Then Lcdat 5 , 64 , "Y4-SP 1"
If Y4_inv_puffer_laden = 1 Then Lcdat 5 , 64 , "Y4-SP 0"


If Inv_rote_lampe = 0 Then Lcdat 6 , 1 , "Rot   1"
If Inv_rote_lampe = 1 Then Lcdat 6 , 1 , "Rot   0"

If Inv_brennerschleife = 0 Then Lcdat 6 , 64 , "   BS 1"
If Inv_brennerschleife = 1 Then Lcdat 6 , 64 , "   BS 0"

Lcdat 8 , 96 , Chr(237)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 32
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------

Blatt_41:                                                        ' 41 41 41 41 41 41 41 41 41 41 41
Lcdat 1 , 1 , "PARAMETER"

Lcdat 2 , 1 , "Boiler max. "
Lcdat 2 , 105 , Boilersollmax ; Chr(248) , 1

Lcdat 3 , 1 , "Boiler min. "
Lcdat 3 , 105 , Boilersollmin ; Chr(248)

Lcdat 4 , 1 , "Aussent. OFF " ;
Lcdat 4 , 105 , Af_aus ; Chr(248)


Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 0 Then Lcdat 5 , 105 , "AUS"
Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 1 Then Lcdat 5 , 105 , "EIN"

Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 0 Then Lcdat 6 , 105 , "AUS"
Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 1 Then Lcdat 6 , 105 , "EIN"




Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 42
If Merker_taster_zurueck = 1 Then Anzeigeseite = 4
If Merker_taster_minus = 1 Then Boilersollmax = Boilersollmax - 1 : Eram_boilersollmax = Boilersollmax
If Merker_taster_plus = 1 Then Boilersollmax = Boilersollmax + 1 : Eram_boilersollmax = Boilersollmax

Return
'-------------------------------------------------------------------------------


Blatt_42:                                                        ' 42 42 42 42 42 42 42 42 42 42 42
Lcdat 1 , 1 , "PARAMETER"

Lcdat 2 , 1 , "Boiler max. "
Lcdat 2 , 105 , Boilersollmax ; Chr(248)

Lcdat 3 , 1 , "Boiler min. "
Lcdat 3 , 105 , Boilersollmin ; Chr(248) , 1

Lcdat 4 , 1 , "Aussent. OFF " ;
Lcdat 4 , 105 , Af_aus ; Chr(248)



Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 0 Then Lcdat 5 , 105 , "AUS"
Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 1 Then Lcdat 5 , 105 , "EIN"

Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 0 Then Lcdat 6 , 105 , "AUS"
Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 1 Then Lcdat 6 , 105 , "EIN"



Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 43
If Merker_taster_zurueck = 1 Then Anzeigeseite = 41
If Merker_taster_minus = 1 Then Boilersollmin = Boilersollmin - 1 : Eram_boilersollmin = Boilersollmin
If Merker_taster_plus = 1 Then Boilersollmin = Boilersollmin + 1 : Eram_boilersollmin = Boilersollmin

Return
'-------------------------------------------------------------------------------


Blatt_43:                                                        ' 43 43 43 43 43 43 43 43 43 43 43
Lcdat 1 , 1 , "PARAMETER"

Lcdat 2 , 1 , "Boiler max. "
Lcdat 2 , 105 , Boilersollmax ; Chr(248)

Lcdat 3 , 1 , "Boiler min. "
Lcdat 3 , 105 , Boilersollmin ; Chr(248)

Lcdat 4 , 1 , "Aussent. OFF " ;
Lcdat 4 , 105 , Af_aus ; Chr(248) , 1



Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 0 Then Lcdat 5 , 105 , "AUS"
Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 1 Then Lcdat 5 , 105 , "EIN"

Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 0 Then Lcdat 6 , 105 , "AUS"
Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 1 Then Lcdat 6 , 105 , "EIN"




Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 44
If Merker_taster_zurueck = 1 Then Anzeigeseite = 42
If Merker_taster_minus = 1 Then Af_aus = Af_aus - 1 : Eram_af_aus = Af_aus
If Merker_taster_plus = 1 Then Af_aus = Af_aus + 1 : Eram_af_aus = Af_aus

Return
'-------------------------------------------------------------------------------


Blatt_44:                                                        ' 44 44 44 44 44 44 44 44 44 44 44
Lcdat 1 , 1 , "PARAMETER"

Lcdat 2 , 1 , "Boiler max. "
Lcdat 2 , 105 , Boilersollmax ; Chr(248)

Lcdat 3 , 1 , "Boiler min. "
Lcdat 3 , 105 , Boilersollmin ; Chr(248)

Lcdat 4 , 1 , "Aussent. OFF " ;
Lcdat 4 , 105 , Af_aus ; Chr(248)


Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 0 Then Lcdat 5 , 105 , "AUS" , 1
Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 1 Then Lcdat 5 , 105 , "EIN" , 1

Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 0 Then Lcdat 6 , 105 , "AUS"
Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 1 Then Lcdat 6 , 105 , "EIN"




Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 45
If Merker_taster_zurueck = 1 Then Anzeigeseite = 43
If Merker_taster_minus = 1 Then Menue_nacht_off = 0 : Eram_menue_nacht_off = Menue_nacht_off
If Merker_taster_plus = 1 Then Menue_nacht_off = 1 : Eram_menue_nacht_off = Menue_nacht_off

Return
'-------------------------------------------------------------------------------


Blatt_45:                                                        ' 45 45 45 45 45 45 45 45 45 45 45
Lcdat 1 , 1 , "PARAMETER"

Lcdat 2 , 1 , "Boiler max. "
Lcdat 2 , 105 , Boilersollmax ; Chr(248)

Lcdat 3 , 1 , "Boiler min. "
Lcdat 3 , 105 , Boilersollmin ; Chr(248)

Lcdat 4 , 1 , "Aussent. OFF " ;
Lcdat 4 , 105 , Af_aus ; Chr(248)



Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 0 Then Lcdat 5 , 105 , "AUS"
Lcdat 5 , 1 , "HKoff 22-06" : If Menue_nacht_off = 1 Then Lcdat 5 , 105 , "EIN"

Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 0 Then Lcdat 6 , 105 , "AUS" , 1
Lcdat 6 , 1 , "HKoff 09-16" : If Menue_tag_off = 1 Then Lcdat 6 , 105 , "EIN" , 1




Lcdat 8 , 96 , "-" ; Chr(237) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 44
If Merker_taster_minus = 1 Then Menue_tag_off = 0 : Eram_menue_tag_off = Menue_tag_off
If Merker_taster_plus = 1 Then Menue_tag_off = 1 : Eram_menue_tag_off = Menue_tag_off

Return
'-------------------------------------------------------------------------------

Blatt_51:                                                        ' 51 51 51 51 51 51 51 51 51 51 51
Lcdat 1 , 1 , "SYSTEM SETUP"

Lcdat 2 , 8 , "Systemwerte" , 1
Lcdat 3 , 8 , "Bus Abfragezeit"
Lcdat 4 , 8 , "Zeit stellen"
Lcdat 5 , 8 , "Ausgaeng setzen"
Lcdat 6 , 8 , "Externes"

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 511
If Merker_taster_zurueck = 1 Then Anzeigeseite = 5
If Merker_taster_minus = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_plus = 1 Then Anzeigeseite = 52

Return
'-------------------------------------------------------------------------------

Blatt_52:                                                        ' 52 52 52 52 52 52 52 52 52 52 52
Lcdat 1 , 1 , "SYSTEM SETUP"

Lcdat 2 , 8 , "Systemwerte"
Lcdat 3 , 8 , "Bus Abfragezeit" , 1
Lcdat 4 , 8 , "Zeit stellen"
Lcdat 5 , 8 , "Ausgaeng setzen"
Lcdat 6 , 8 , "Externes"

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 521
If Merker_taster_zurueck = 1 Then Anzeigeseite = 5
If Merker_taster_minus = 1 Then Anzeigeseite = 51
If Merker_taster_plus = 1 Then Anzeigeseite = 53

Return
'-------------------------------------------------------------------------------

Blatt_53:                                                        ' 53 53 53 53 53 53 53 53 53 53 53
Lcdat 1 , 1 , "SYSTEM SETUP"

Lcdat 2 , 8 , "Systemwerte"
Lcdat 3 , 8 , "Bus Abfragezeit"
Lcdat 4 , 8 , "Zeit stellen" , 1
Lcdat 5 , 8 , "Ausgaeng setzen"
Lcdat 6 , 8 , "Externes"

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 531
If Merker_taster_zurueck = 1 Then Anzeigeseite = 5
If Merker_taster_minus = 1 Then Anzeigeseite = 52
If Merker_taster_plus = 1 Then Anzeigeseite = 54

Return
'-------------------------------------------------------------------------------

Blatt_54:                                                        ' 54 54 54 54 54 54 54 54 54 54 54
Lcdat 1 , 1 , "SYSTEM SETUP"

Lcdat 2 , 8 , "Systemwerte"
Lcdat 3 , 8 , "Bus Abfragezeit"
Lcdat 4 , 8 , "Zeit stellen"
Lcdat 5 , 8 , "Ausgaeng setzen" , 1
Lcdat 6 , 8 , "Externes"

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236)
If Merker_taster_enter = 1 Then Anzeigeseite = 541
If Merker_taster_zurueck = 1 Then Anzeigeseite = 5
If Merker_taster_minus = 1 Then Anzeigeseite = 53
If Merker_taster_plus = 1 Then Anzeigeseite = 55

Return
'-------------------------------------------------------------------------------


Blatt_55:                                                        ' 55 55 55 55 55 55 55 55 55 55 55
Lcdat 1 , 1 , "SYSTEM SETUP"

Lcdat 2 , 8 , "Systemwerte"
Lcdat 3 , 8 , "Bus Abfragezeit"
Lcdat 4 , 8 , "Zeit stellen"
Lcdat 5 , 8 , "Ausgaeng setzen"
Lcdat 6 , 8 , "Externes" , 1

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236)
If Merker_taster_enter = 1 Then Anzeigeseite = 551
If Merker_taster_zurueck = 1 Then Anzeigeseite = 5
If Merker_taster_minus = 1 Then Anzeigeseite = 54
If Merker_taster_plus = 1 Then Anzeigeseite = Anzeigeseite

Return
'-------------------------------------------------------------------------------


Blatt_511:                                                       ' 511 511 511 511 511 511 511 511
Lcdat 1 , 1 , "SYSTEMWERTE"


Lcdat 3 , 1 , "Holz ein ab" , 1
Lcdat 3 , 105 , Holzbetriebswert ; Chr(248) , 1
Lcdat 4 , 1 , "Puffer on ab"
Lcdat 4 , 105 , Pufferbetriebswert ; Chr(248)
Lcdat 5 , 1 , "PU>Boi Diff"
Lcdat 5 , 105 , Puffer2boilersoll ; Chr(248)
Lcdat 6 , 1 , "Rot ab"
Lcdat 6 , 105 , Rote_lampe ; Chr(248)





Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 512
If Merker_taster_zurueck = 1 Then Anzeigeseite = 51
If Merker_taster_minus = 1 Then Holzbetriebswert = Holzbetriebswert -1 : Eram_holzbetriebswert = Holzbetriebswert
If Merker_taster_plus = 1 Then Holzbetriebswert = Holzbetriebswert + 1 : Eram_holzbetriebswert = Holzbetriebswert

Return
'-------------------------------------------------------------------------------

Blatt_512:                                                       ' 512 512 512 512 512 512 512 512
Lcdat 1 , 1 , "SYSTEMWERTE"


Lcdat 3 , 1 , "Holz ein ab"
Lcdat 3 , 105 , Holzbetriebswert ; Chr(248)
Lcdat 4 , 1 , "Puffer on ab" , 1
Lcdat 4 , 105 , Pufferbetriebswert ; Chr(248) , 1
Lcdat 5 , 1 , "PU>Boi Diff"
Lcdat 5 , 105 , Puffer2boilersoll ; Chr(248)
Lcdat 6 , 1 , "Rot ab"
Lcdat 6 , 105 , Rote_lampe ; Chr(248)





Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 513
If Merker_taster_zurueck = 1 Then Anzeigeseite = 511
If Merker_taster_minus = 1 Then Pufferbetriebswert = Pufferbetriebswert -1 : Eram_pufferbetriebswert = Pufferbetriebswert
If Merker_taster_plus = 1 Then Pufferbetriebswert = Pufferbetriebswert + 1 : Eram_pufferbetriebswert = Pufferbetriebswert

Return
'-------------------------------------------------------------------------------

Blatt_513:                                                       ' 513 513 513 513 513 513 513 513
Lcdat 1 , 1 , "SYSTEMWERTE"


Lcdat 3 , 1 , "Holz ein ab"
Lcdat 3 , 105 , Holzbetriebswert ; Chr(248)
Lcdat 4 , 1 , "Puffer on ab"
Lcdat 4 , 105 , Pufferbetriebswert ; Chr(248)
Lcdat 5 , 1 , "PU>Boi Diff" , 1
Lcdat 5 , 105 , Puffer2boilersoll ; Chr(248) , 1
Lcdat 6 , 1 , "Rot ab"
Lcdat 6 , 105 , Rote_lampe ; Chr(248)





Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 514
If Merker_taster_zurueck = 1 Then Anzeigeseite = 512
If Merker_taster_minus = 1 Then Puffer2boilersoll = Puffer2boilersoll -1 : Eram_puffer2boilersoll = Puffer2boilersoll
If Merker_taster_plus = 1 Then Puffer2boilersoll = Puffer2boilersoll + 1 : Eram_puffer2boilersoll = Puffer2boilersoll

Return
'-------------------------------------------------------------------------------

Blatt_514:                                                       ' 514 514 514 514 514 514 514 514
Lcdat 1 , 1 , "SYSTEMWERTE"


Lcdat 3 , 1 , "Holz ein ab"
Lcdat 3 , 105 , Holzbetriebswert ; Chr(248)
Lcdat 4 , 1 , "Puffer on ab"
Lcdat 4 , 105 , Pufferbetriebswert ; Chr(248)
Lcdat 5 , 1 , "PU>Boi Diff"
Lcdat 5 , 105 , Puffer2boilersoll ; Chr(248)
Lcdat 6 , 1 , "Rot ab" , 1
Lcdat 6 , 105 , Rote_lampe ; Chr(248) , 1





Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236)
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 513
If Merker_taster_minus = 1 Then Rote_lampe = Rote_lampe -1 : Eram_rote_lampe = Rote_lampe
If Merker_taster_plus = 1 Then Rote_lampe = Rote_lampe + 1 : Eram_rote_lampe = Rote_lampe

Return
'-------------------------------------------------------------------------------







Blatt_521:                                                       ' 521 521 521 521 521 521 521 521
Lcdat 1 , 1 , "Bus Abfragezeit"

Lcdat 3 , 8 , "alle " ; Bus_abfragezeit ; " sec  "



Lcdat 8 , 96 , "-" ; Chr(237) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 52
If Merker_taster_minus = 1 Then Bus_abfragezeit = Bus_abfragezeit - 1 : Eram_bus_abfragezeit = Bus_abfragezeit
If Merker_taster_plus = 1 Then Bus_abfragezeit = Bus_abfragezeit + 1 : Eram_bus_abfragezeit = Bus_abfragezeit

Return
'-------------------------------------------------------------------------------

Blatt_531:                                                       ' 531 531 531 531 531 531 531 531
Lcdat 1 , 1 , "STD. STELLEN"

Lcdat 3 , 8 , _hour , 1
Lcdat 3 , 24 , ":"
Lcdat 3 , 32 , _min
Lcdat 3 , 48 , ":"
Lcdat 3 , 56 , _sec

If Wochentag = 1 Then Lcdat 5 , 8 , "Montag    "
If Wochentag = 2 Then Lcdat 5 , 8 , "Dienstag  "
If Wochentag = 3 Then Lcdat 5 , 8 , "Mittwoch  "
If Wochentag = 4 Then Lcdat 5 , 8 , "Donnerstag"
If Wochentag = 5 Then Lcdat 5 , 8 , "Freitag   "
If Wochentag = 6 Then Lcdat 5 , 8 , "Samstag   "
If Wochentag = 7 Then Lcdat 5 , 8 , "Sonntag   "

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 532
If Merker_taster_zurueck = 1 Then Anzeigeseite = 53
If Merker_taster_minus = 1 Then _hour = _hour -1
If Merker_taster_plus = 1 Then _hour = _hour + 1

Return
'-------------------------------------------------------------------------------

Blatt_532:                                                       ' 532 532 532 532 532 532 532 532
Lcdat 1 , 1 , "MIN. STELLEN"

Lcdat 3 , 8 , _hour
Lcdat 3 , 24 , ":"
Lcdat 3 , 32 , _min , 1
Lcdat 3 , 48 , ":"
Lcdat 3 , 56 , _sec

If Wochentag = 1 Then Lcdat 5 , 8 , "Montag    "
If Wochentag = 2 Then Lcdat 5 , 8 , "Dienstag  "
If Wochentag = 3 Then Lcdat 5 , 8 , "Mittwoch  "
If Wochentag = 4 Then Lcdat 5 , 8 , "Donnerstag"
If Wochentag = 5 Then Lcdat 5 , 8 , "Freitag   "
If Wochentag = 6 Then Lcdat 5 , 8 , "Samstag   "
If Wochentag = 7 Then Lcdat 5 , 8 , "Sonntag   "

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 533
If Merker_taster_zurueck = 1 Then Anzeigeseite = 531
If Merker_taster_minus = 1 Then _min = _min -1
If Merker_taster_plus = 1 Then _min = _min + 1

Return
'-------------------------------------------------------------------------------

Blatt_533:                                                       ' 533 533 533 533 533 533 533 533
Lcdat 1 , 1 , "SEC. STELLEN"

Lcdat 3 , 8 , _hour
Lcdat 3 , 24 , ":"
Lcdat 3 , 32 , _min
Lcdat 3 , 48 , ":"
Lcdat 3 , 56 , _sec , 1

If Wochentag = 1 Then Lcdat 5 , 8 , "Montag    "
If Wochentag = 2 Then Lcdat 5 , 8 , "Dienstag  "
If Wochentag = 3 Then Lcdat 5 , 8 , "Mittwoch  "
If Wochentag = 4 Then Lcdat 5 , 8 , "Donnerstag"
If Wochentag = 5 Then Lcdat 5 , 8 , "Freitag   "
If Wochentag = 6 Then Lcdat 5 , 8 , "Samstag   "
If Wochentag = 7 Then Lcdat 5 , 8 , "Sonntag   "

Lcdat 8 , 96 , "-" ; Chr(237) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 534
If Merker_taster_zurueck = 1 Then Anzeigeseite = 532
If Merker_taster_minus = 1 Then _sec = _sec -1
If Merker_taster_plus = 1 Then _sec = _sec + 1

Return
'-------------------------------------------------------------------------------

Blatt_534:                                                       ' 534 534 534 534 534 534 534 534
Lcdat 1 , 1 , "WOCHENTAG"

Lcdat 3 , 8 , _hour
Lcdat 3 , 24 , ":"
Lcdat 3 , 32 , _min
Lcdat 3 , 48 , ":"
Lcdat 3 , 56 , _sec

If Wochentag = 1 Then Lcdat 5 , 8 , "Montag    " , 1
If Wochentag = 2 Then Lcdat 5 , 8 , "Dienstag  " , 1
If Wochentag = 3 Then Lcdat 5 , 8 , "Mittwoch  " , 1
If Wochentag = 4 Then Lcdat 5 , 8 , "Donnerstag" , 1
If Wochentag = 5 Then Lcdat 5 , 8 , "Freitag   " , 1
If Wochentag = 6 Then Lcdat 5 , 8 , "Samstag   " , 1
If Wochentag = 7 Then Lcdat 5 , 8 , "Sonntag   " , 1

Lcdat 8 , 96 , "-" ; Chr(237) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 533
If Merker_taster_minus = 1 Then Wochentag = Wochentag -1
If Merker_taster_plus = 1 Then Wochentag = Wochentag + 1

If Wochentag > 7 Then Wochentag = 1
If Wochentag < 1 Then Wochentag = 7

Return
'-------------------------------------------------------------------------------

Blatt_541:                                                       ' 541 541 541 541 541 541 541 541
Lcdat 1 , 1 , "AUSGAENGE SETZEN"

If M1_modus = 0 Then Lcdat 2 , 1 , "M1-Aus " , 1
If M1_modus = 1 Then Lcdat 2 , 1 , "M1-Ein " , 1
If M1_modus = 2 Then Lcdat 2 , 1 , "M1-Auto" , 1
If M1_modus > 2 Then Lcdat 2 , 1 , "M1- " ; M1_modus , 1

If M2_modus = 0 Then Lcdat 3 , 1 , "M2-Aus "
If M2_modus = 1 Then Lcdat 3 , 1 , "M2-Ein "
If M2_modus = 2 Then Lcdat 3 , 1 , "M2-Auto"
If M2_modus > 2 Then Lcdat 3 , 1 , "M2- " ; M2_modus

If M3_modus = 0 Then Lcdat 4 , 1 , "M3-Aus "
If M3_modus = 1 Then Lcdat 4 , 1 , "M3-Ein "
If M3_modus = 2 Then Lcdat 4 , 1 , "M3-Auto"
If M3_modus > 2 Then Lcdat 4 , 1 , "M3- " ; M3_modus

If M4_modus = 0 Then Lcdat 5 , 1 , "M4-Aus "
If M4_modus = 1 Then Lcdat 5 , 1 , "M4-Ein "
If M4_modus = 2 Then Lcdat 5 , 1 , "M4-Auto"
If M4_modus > 2 Then Lcdat 5 , 1 , "M4- " ; M4_modus

If Y1_modus = 0 Then Lcdat 2 , 64 , "Y1-Aus "
If Y1_modus = 1 Then Lcdat 2 , 64 , "Y1-Ein "
If Y1_modus = 2 Then Lcdat 2 , 64 , "Y1-Auto"
If Y1_modus > 2 Then Lcdat 2 , 64 , "Y1- " ; Y1_modus

If Y2_modus = 0 Then Lcdat 3 , 64 , "Y2-Aus "
If Y2_modus = 1 Then Lcdat 3 , 64 , "Y2-Ein "
If Y2_modus = 2 Then Lcdat 3 , 64 , "Y2-Auto"
If Y2_modus > 2 Then Lcdat 3 , 64 , "Y2- " ; Y2_modus

If Y3_modus = 0 Then Lcdat 4 , 64 , "Y3-Aus "
If Y3_modus = 1 Then Lcdat 4 , 64 , "Y3-Ein "
If Y3_modus = 2 Then Lcdat 4 , 64 , "Y3-Auto"
If Y3_modus > 2 Then Lcdat 4 , 64 , "Y3- " ; Y3_modus

If Y4_modus = 0 Then Lcdat 5 , 64 , "Y4-Aus "
If Y4_modus = 1 Then Lcdat 5 , 64 , "Y4-Ein "
If Y4_modus = 2 Then Lcdat 5 , 64 , "Y4-Auto"
If Y4_modus > 2 Then Lcdat 5 , 64 , "Y4- " ; Y4_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 542
If Merker_taster_zurueck = 1 Then Anzeigeseite = 54
If Merker_taster_minus = 1 Then M1_modus = M1_modus -1 : Eram_m1_modus = M1_modus
If Merker_taster_plus = 1 Then M1_modus = M1_modus + 1 : Eram_m1_modus = M1_modus

Return
'-------------------------------------------------------------------------------

Blatt_542:                                                       ' 542 542 542 542 542 542 542 542
Lcdat 1 , 1 , "AUSGAENGE SETZEN"

If M1_modus = 0 Then Lcdat 2 , 1 , "M1-Aus "
If M1_modus = 1 Then Lcdat 2 , 1 , "M1-Ein "
If M1_modus = 2 Then Lcdat 2 , 1 , "M1-Auto"
If M1_modus > 2 Then Lcdat 2 , 1 , "M1- " ; M1_modus

If M2_modus = 0 Then Lcdat 3 , 1 , "M2-Aus " , 1
If M2_modus = 1 Then Lcdat 3 , 1 , "M2-Ein " , 1
If M2_modus = 2 Then Lcdat 3 , 1 , "M2-Auto" , 1
If M2_modus > 2 Then Lcdat 3 , 1 , "M2- " ; M2_modus , 1

If M3_modus = 0 Then Lcdat 4 , 1 , "M3-Aus "
If M3_modus = 1 Then Lcdat 4 , 1 , "M3-Ein "
If M3_modus = 2 Then Lcdat 4 , 1 , "M3-Auto"
If M3_modus > 2 Then Lcdat 4 , 1 , "M3- " ; M3_modus

If M4_modus = 0 Then Lcdat 5 , 1 , "M4-Aus "
If M4_modus = 1 Then Lcdat 5 , 1 , "M4-Ein "
If M4_modus = 2 Then Lcdat 5 , 1 , "M4-Auto"
If M4_modus > 2 Then Lcdat 5 , 1 , "M4- " ; M4_modus

If Y1_modus = 0 Then Lcdat 2 , 64 , "Y1-Aus "
If Y1_modus = 1 Then Lcdat 2 , 64 , "Y1-Ein "
If Y1_modus = 2 Then Lcdat 2 , 64 , "Y1-Auto"
If Y1_modus > 2 Then Lcdat 2 , 64 , "Y1- " ; Y1_modus

If Y2_modus = 0 Then Lcdat 3 , 64 , "Y2-Aus "
If Y2_modus = 1 Then Lcdat 3 , 64 , "Y2-Ein "
If Y2_modus = 2 Then Lcdat 3 , 64 , "Y2-Auto"
If Y2_modus > 2 Then Lcdat 3 , 64 , "Y2- " ; Y2_modus

If Y3_modus = 0 Then Lcdat 4 , 64 , "Y3-Aus "
If Y3_modus = 1 Then Lcdat 4 , 64 , "Y3-Ein "
If Y3_modus = 2 Then Lcdat 4 , 64 , "Y3-Auto"
If Y3_modus > 2 Then Lcdat 4 , 64 , "Y3- " ; Y3_modus

If Y4_modus = 0 Then Lcdat 5 , 64 , "Y4-Aus "
If Y4_modus = 1 Then Lcdat 5 , 64 , "Y4-Ein "
If Y4_modus = 2 Then Lcdat 5 , 64 , "Y4-Auto"
If Y4_modus > 2 Then Lcdat 5 , 64 , "Y4- " ; Y4_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 543
If Merker_taster_zurueck = 1 Then Anzeigeseite = 541
If Merker_taster_minus = 1 Then M2_modus = M2_modus -1 : Eram_m2_modus = M2_modus
If Merker_taster_plus = 1 Then M2_modus = M2_modus + 1 : Eram_m2_modus = M2_modus

Return
'-------------------------------------------------------------------------------

Blatt_543:                                                       ' 543 543 543 543 543 543 543 543
Lcdat 1 , 1 , "AUSGAENGE SETZEN"

If M1_modus = 0 Then Lcdat 2 , 1 , "M1-Aus "
If M1_modus = 1 Then Lcdat 2 , 1 , "M1-Ein "
If M1_modus = 2 Then Lcdat 2 , 1 , "M1-Auto"
If M1_modus > 2 Then Lcdat 2 , 1 , "M1- " ; M1_modus

If M2_modus = 0 Then Lcdat 3 , 1 , "M2-Aus "
If M2_modus = 1 Then Lcdat 3 , 1 , "M2-Ein "
If M2_modus = 2 Then Lcdat 3 , 1 , "M2-Auto"
If M2_modus > 2 Then Lcdat 3 , 1 , "M2- " ; M2_modus

If M3_modus = 0 Then Lcdat 4 , 1 , "M3-Aus " , 1
If M3_modus = 1 Then Lcdat 4 , 1 , "M3-Ein " , 1
If M3_modus = 2 Then Lcdat 4 , 1 , "M3-Auto" , 1
If M3_modus > 2 Then Lcdat 4 , 1 , "M3- " ; M3_modus , 1

If M4_modus = 0 Then Lcdat 5 , 1 , "M4-Aus "
If M4_modus = 1 Then Lcdat 5 , 1 , "M4-Ein "
If M4_modus = 2 Then Lcdat 5 , 1 , "M4-Auto"
If M4_modus > 2 Then Lcdat 5 , 1 , "M4- " ; M4_modus

If Y1_modus = 0 Then Lcdat 2 , 64 , "Y1-Aus "
If Y1_modus = 1 Then Lcdat 2 , 64 , "Y1-Ein "
If Y1_modus = 2 Then Lcdat 2 , 64 , "Y1-Auto"
If Y1_modus > 2 Then Lcdat 2 , 64 , "Y1- " ; Y1_modus

If Y2_modus = 0 Then Lcdat 3 , 64 , "Y2-Aus "
If Y2_modus = 1 Then Lcdat 3 , 64 , "Y2-Ein "
If Y2_modus = 2 Then Lcdat 3 , 64 , "Y2-Auto"
If Y2_modus > 2 Then Lcdat 3 , 64 , "Y2- " ; Y2_modus

If Y3_modus = 0 Then Lcdat 4 , 64 , "Y3-Aus "
If Y3_modus = 1 Then Lcdat 4 , 64 , "Y3-Ein "
If Y3_modus = 2 Then Lcdat 4 , 64 , "Y3-Auto"
If Y3_modus > 2 Then Lcdat 4 , 64 , "Y3- " ; Y3_modus

If Y4_modus = 0 Then Lcdat 5 , 64 , "Y4-Aus "
If Y4_modus = 1 Then Lcdat 5 , 64 , "Y4-Ein "
If Y4_modus = 2 Then Lcdat 5 , 64 , "Y4-Auto"
If Y4_modus > 2 Then Lcdat 5 , 64 , "Y4- " ; Y4_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 544
If Merker_taster_zurueck = 1 Then Anzeigeseite = 542
If Merker_taster_minus = 1 Then M3_modus = M3_modus -1 : Eram_m3_modus = M3_modus
If Merker_taster_plus = 1 Then M3_modus = M3_modus + 1 : Eram_m3_modus = M3_modus

Return
'-------------------------------------------------------------------------------

Blatt_544:                                                       ' 544 544 544 544 544 544 544 544
Lcdat 1 , 1 , "AUSGAENGE SETZEN"


If M1_modus = 0 Then Lcdat 2 , 1 , "M1-Aus "
If M1_modus = 1 Then Lcdat 2 , 1 , "M1-Ein "
If M1_modus = 2 Then Lcdat 2 , 1 , "M1-Auto"
If M1_modus > 2 Then Lcdat 2 , 1 , "M1- " ; M1_modus

If M2_modus = 0 Then Lcdat 3 , 1 , "M2-Aus "
If M2_modus = 1 Then Lcdat 3 , 1 , "M2-Ein "
If M2_modus = 2 Then Lcdat 3 , 1 , "M2-Auto"
If M2_modus > 2 Then Lcdat 3 , 1 , "M2- " ; M2_modus

If M3_modus = 0 Then Lcdat 4 , 1 , "M3-Aus "
If M3_modus = 1 Then Lcdat 4 , 1 , "M3-Ein "
If M3_modus = 2 Then Lcdat 4 , 1 , "M3-Auto"
If M3_modus > 2 Then Lcdat 4 , 1 , "M3- " ; M3_modus

If M4_modus = 0 Then Lcdat 5 , 1 , "M4-Aus " , 1
If M4_modus = 1 Then Lcdat 5 , 1 , "M4-Ein " , 1
If M4_modus = 2 Then Lcdat 5 , 1 , "M4-Auto" , 1
If M4_modus > 2 Then Lcdat 5 , 1 , "M4- " ; M4_modus , 1

If Y1_modus = 0 Then Lcdat 2 , 64 , "Y1-Aus "
If Y1_modus = 1 Then Lcdat 2 , 64 , "Y1-Ein "
If Y1_modus = 2 Then Lcdat 2 , 64 , "Y1-Auto"
If Y1_modus > 2 Then Lcdat 2 , 64 , "Y1- " ; Y1_modus

If Y2_modus = 0 Then Lcdat 3 , 64 , "Y2-Aus "
If Y2_modus = 1 Then Lcdat 3 , 64 , "Y2-Ein "
If Y2_modus = 2 Then Lcdat 3 , 64 , "Y2-Auto"
If Y2_modus > 2 Then Lcdat 3 , 64 , "Y2- " ; Y2_modus

If Y3_modus = 0 Then Lcdat 4 , 64 , "Y3-Aus "
If Y3_modus = 1 Then Lcdat 4 , 64 , "Y3-Ein "
If Y3_modus = 2 Then Lcdat 4 , 64 , "Y3-Auto"
If Y3_modus > 2 Then Lcdat 4 , 64 , "Y3- " ; Y3_modus

If Y4_modus = 0 Then Lcdat 5 , 64 , "Y4-Aus "
If Y4_modus = 1 Then Lcdat 5 , 64 , "Y4-Ein "
If Y4_modus = 2 Then Lcdat 5 , 64 , "Y4-Auto"
If Y4_modus > 2 Then Lcdat 5 , 64 , "Y4- " ; Y4_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 545
If Merker_taster_zurueck = 1 Then Anzeigeseite = 543
If Merker_taster_minus = 1 Then M4_modus = M4_modus -1 : Eram_m4_modus = M4_modus
If Merker_taster_plus = 1 Then M4_modus = M4_modus + 1 : Eram_m4_modus = M4_modus

Return
'-------------------------------------------------------------------------------

Blatt_545:                                                       ' 545 545 545 545 545 545 545 545
Lcdat 1 , 1 , "AUSGAENGE SETZEN"

If M1_modus = 0 Then Lcdat 2 , 1 , "M1-Aus "
If M1_modus = 1 Then Lcdat 2 , 1 , "M1-Ein "
If M1_modus = 2 Then Lcdat 2 , 1 , "M1-Auto"
If M1_modus > 2 Then Lcdat 2 , 1 , "M1- " ; M1_modus

If M2_modus = 0 Then Lcdat 3 , 1 , "M2-Aus "
If M2_modus = 1 Then Lcdat 3 , 1 , "M2-Ein "
If M2_modus = 2 Then Lcdat 3 , 1 , "M2-Auto"
If M2_modus > 2 Then Lcdat 3 , 1 , "M2- " ; M2_modus

If M3_modus = 0 Then Lcdat 4 , 1 , "M3-Aus "
If M3_modus = 1 Then Lcdat 4 , 1 , "M3-Ein "
If M3_modus = 2 Then Lcdat 4 , 1 , "M3-Auto"
If M3_modus > 2 Then Lcdat 4 , 1 , "M3- " ; M3_modus

If M4_modus = 0 Then Lcdat 5 , 1 , "M4-Aus "
If M4_modus = 1 Then Lcdat 5 , 1 , "M4-Ein "
If M4_modus = 2 Then Lcdat 5 , 1 , "M4-Auto"
If M4_modus > 2 Then Lcdat 5 , 1 , "M4- " ; M4_modus

If Y1_modus = 0 Then Lcdat 2 , 64 , "Y1-Aus " , 1
If Y1_modus = 1 Then Lcdat 2 , 64 , "Y1-Ein " , 1
If Y1_modus = 2 Then Lcdat 2 , 64 , "Y1-Auto" , 1
If Y1_modus > 2 Then Lcdat 2 , 64 , "Y1- " ; Y1_modus , 1

If Y2_modus = 0 Then Lcdat 3 , 64 , "Y2-Aus "
If Y2_modus = 1 Then Lcdat 3 , 64 , "Y2-Ein "
If Y2_modus = 2 Then Lcdat 3 , 64 , "Y2-Auto"
If Y2_modus > 2 Then Lcdat 3 , 64 , "Y2- " ; Y2_modus

If Y3_modus = 0 Then Lcdat 4 , 64 , "Y3-Aus "
If Y3_modus = 1 Then Lcdat 4 , 64 , "Y3-Ein "
If Y3_modus = 2 Then Lcdat 4 , 64 , "Y3-Auto"
If Y3_modus > 2 Then Lcdat 4 , 64 , "Y3- " ; Y3_modus

If Y4_modus = 0 Then Lcdat 5 , 64 , "Y4-Aus "
If Y4_modus = 1 Then Lcdat 5 , 64 , "Y4-Ein "
If Y4_modus = 2 Then Lcdat 5 , 64 , "Y4-Auto"
If Y4_modus > 2 Then Lcdat 5 , 64 , "Y4- " ; Y4_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 546
If Merker_taster_zurueck = 1 Then Anzeigeseite = 544
If Merker_taster_minus = 1 Then Y1_modus = Y1_modus -1 : Eram_y1_modus = Y1_modus
If Merker_taster_plus = 1 Then Y1_modus = Y1_modus + 1 : Eram_y1_modus = Y1_modus

Return
'-------------------------------------------------------------------------------

Blatt_546:                                                       ' 546 546 546 546 546 546 546 546
Lcdat 1 , 1 , "AUSGAENGE SETZEN"

If M1_modus = 0 Then Lcdat 2 , 1 , "M1-Aus "
If M1_modus = 1 Then Lcdat 2 , 1 , "M1-Ein "
If M1_modus = 2 Then Lcdat 2 , 1 , "M1-Auto"
If M1_modus > 2 Then Lcdat 2 , 1 , "M1- " ; M1_modus

If M2_modus = 0 Then Lcdat 3 , 1 , "M2-Aus "
If M2_modus = 1 Then Lcdat 3 , 1 , "M2-Ein "
If M2_modus = 2 Then Lcdat 3 , 1 , "M2-Auto"
If M2_modus > 2 Then Lcdat 3 , 1 , "M2- " ; M2_modus

If M3_modus = 0 Then Lcdat 4 , 1 , "M3-Aus "
If M3_modus = 1 Then Lcdat 4 , 1 , "M3-Ein "
If M3_modus = 2 Then Lcdat 4 , 1 , "M3-Auto"
If M3_modus > 2 Then Lcdat 4 , 1 , "M3- " ; M3_modus

If M4_modus = 0 Then Lcdat 5 , 1 , "M4-Aus "
If M4_modus = 1 Then Lcdat 5 , 1 , "M4-Ein "
If M4_modus = 2 Then Lcdat 5 , 1 , "M4-Auto"
If M4_modus > 2 Then Lcdat 5 , 1 , "M4- " ; M4_modus

If Y1_modus = 0 Then Lcdat 2 , 64 , "Y1-Aus "
If Y1_modus = 1 Then Lcdat 2 , 64 , "Y1-Ein "
If Y1_modus = 2 Then Lcdat 2 , 64 , "Y1-Auto"
If Y1_modus > 2 Then Lcdat 2 , 64 , "Y1- " ; Y1_modus

If Y2_modus = 0 Then Lcdat 3 , 64 , "Y2-Aus " , 1
If Y2_modus = 1 Then Lcdat 3 , 64 , "Y2-Ein " , 1
If Y2_modus = 2 Then Lcdat 3 , 64 , "Y2-Auto" , 1
If Y2_modus > 2 Then Lcdat 3 , 64 , "Y2- " ; Y2_modus , 1

If Y3_modus = 0 Then Lcdat 4 , 64 , "Y3-Aus "
If Y3_modus = 1 Then Lcdat 4 , 64 , "Y3-Ein "
If Y3_modus = 2 Then Lcdat 4 , 64 , "Y3-Auto"
If Y3_modus > 2 Then Lcdat 4 , 64 , "Y3- " ; Y3_modus

If Y4_modus = 0 Then Lcdat 5 , 64 , "Y4-Aus "
If Y4_modus = 1 Then Lcdat 5 , 64 , "Y4-Ein "
If Y4_modus = 2 Then Lcdat 5 , 64 , "Y4-Auto"
If Y4_modus > 2 Then Lcdat 5 , 64 , "Y4- " ; Y4_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 547
If Merker_taster_zurueck = 1 Then Anzeigeseite = 545
If Merker_taster_minus = 1 Then Y2_modus = Y2_modus -1 : Eram_y2_modus = Y2_modus
If Merker_taster_plus = 1 Then Y2_modus = Y2_modus + 1 : Eram_y2_modus = Y2_modus

Return
'-------------------------------------------------------------------------------

Blatt_547:                                                       ' 547 547 547 547 547 547 547 547
Lcdat 1 , 1 , "AUSGAENGE SETZEN"

If M1_modus = 0 Then Lcdat 2 , 1 , "M1-Aus "
If M1_modus = 1 Then Lcdat 2 , 1 , "M1-Ein "
If M1_modus = 2 Then Lcdat 2 , 1 , "M1-Auto"
If M1_modus > 2 Then Lcdat 2 , 1 , "M1- " ; M1_modus

If M2_modus = 0 Then Lcdat 3 , 1 , "M2-Aus "
If M2_modus = 1 Then Lcdat 3 , 1 , "M2-Ein "
If M2_modus = 2 Then Lcdat 3 , 1 , "M2-Auto"
If M2_modus > 2 Then Lcdat 3 , 1 , "M2- " ; M2_modus

If M3_modus = 0 Then Lcdat 4 , 1 , "M3-Aus "
If M3_modus = 1 Then Lcdat 4 , 1 , "M3-Ein "
If M3_modus = 2 Then Lcdat 4 , 1 , "M3-Auto"
If M3_modus > 2 Then Lcdat 4 , 1 , "M3- " ; M3_modus

If M4_modus = 0 Then Lcdat 5 , 1 , "M4-Aus "
If M4_modus = 1 Then Lcdat 5 , 1 , "M4-Ein "
If M4_modus = 2 Then Lcdat 5 , 1 , "M4-Auto"
If M4_modus > 2 Then Lcdat 5 , 1 , "M4- " ; M4_modus

If Y1_modus = 0 Then Lcdat 2 , 64 , "Y1-Aus "
If Y1_modus = 1 Then Lcdat 2 , 64 , "Y1-Ein "
If Y1_modus = 2 Then Lcdat 2 , 64 , "Y1-Auto"
If Y1_modus > 2 Then Lcdat 2 , 64 , "Y1- " ; Y1_modus

If Y2_modus = 0 Then Lcdat 3 , 64 , "Y2-Aus "
If Y2_modus = 1 Then Lcdat 3 , 64 , "Y2-Ein "
If Y2_modus = 2 Then Lcdat 3 , 64 , "Y2-Auto"
If Y2_modus > 2 Then Lcdat 3 , 64 , "Y2- " ; Y2_modus

If Y3_modus = 0 Then Lcdat 4 , 64 , "Y3-Aus " , 1
If Y3_modus = 1 Then Lcdat 4 , 64 , "Y3-Ein " , 1
If Y3_modus = 2 Then Lcdat 4 , 64 , "Y3-Auto" , 1
If Y3_modus > 2 Then Lcdat 4 , 64 , "Y3- " ; Y3_modus , 1

If Y4_modus = 0 Then Lcdat 5 , 64 , "Y4-Aus "
If Y4_modus = 1 Then Lcdat 5 , 64 , "Y4-Ein "
If Y4_modus = 2 Then Lcdat 5 , 64 , "Y4-Auto"
If Y4_modus > 2 Then Lcdat 5 , 64 , "Y4- " ; Y4_modus

Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 548
If Merker_taster_zurueck = 1 Then Anzeigeseite = 546
If Merker_taster_minus = 1 Then Y3_modus = Y3_modus -1 : Eram_y3_modus = Y3_modus
If Merker_taster_plus = 1 Then Y3_modus = Y3_modus + 1 : Eram_y3_modus = Y3_modus

Return
'-------------------------------------------------------------------------------

Blatt_548:                                                       ' 548 548 548 548 548 548 548 548
Lcdat 1 , 1 , "AUSGAENGE SETZEN"

If M1_modus = 0 Then Lcdat 2 , 1 , "M1-Aus "
If M1_modus = 1 Then Lcdat 2 , 1 , "M1-Ein "
If M1_modus = 2 Then Lcdat 2 , 1 , "M1-Auto"
If M1_modus > 2 Then Lcdat 2 , 1 , "M1- " ; M1_modus

If M2_modus = 0 Then Lcdat 3 , 1 , "M2-Aus "
If M2_modus = 1 Then Lcdat 3 , 1 , "M2-Ein "
If M2_modus = 2 Then Lcdat 3 , 1 , "M2-Auto"
If M2_modus > 2 Then Lcdat 3 , 1 , "M2- " ; M2_modus

If M3_modus = 0 Then Lcdat 4 , 1 , "M3-Aus "
If M3_modus = 1 Then Lcdat 4 , 1 , "M3-Ein "
If M3_modus = 2 Then Lcdat 4 , 1 , "M3-Auto"
If M3_modus > 2 Then Lcdat 4 , 1 , "M3- " ; M3_modus

If M4_modus = 0 Then Lcdat 5 , 1 , "M4-Aus "
If M4_modus = 1 Then Lcdat 5 , 1 , "M4-Ein "
If M4_modus = 2 Then Lcdat 5 , 1 , "M4-Auto"
If M4_modus > 2 Then Lcdat 5 , 1 , "M4- " ; M4_modus

If Y1_modus = 0 Then Lcdat 2 , 64 , "Y1-Aus "
If Y1_modus = 1 Then Lcdat 2 , 64 , "Y1-Ein "
If Y1_modus = 2 Then Lcdat 2 , 64 , "Y1-Auto"
If Y1_modus > 2 Then Lcdat 2 , 64 , "Y1- " ; Y1_modus

If Y2_modus = 0 Then Lcdat 3 , 64 , "Y2-Aus "
If Y2_modus = 1 Then Lcdat 3 , 64 , "Y2-Ein "
If Y2_modus = 2 Then Lcdat 3 , 64 , "Y2-Auto"
If Y2_modus > 2 Then Lcdat 3 , 64 , "Y2- " ; Y2_modus

If Y3_modus = 0 Then Lcdat 4 , 64 , "Y3-Aus "
If Y3_modus = 1 Then Lcdat 4 , 64 , "Y3-Ein "
If Y3_modus = 2 Then Lcdat 4 , 64 , "Y3-Auto"
If Y3_modus > 2 Then Lcdat 4 , 64 , "Y3- " ; Y3_modus

If Y4_modus = 0 Then Lcdat 5 , 64 , "Y4-Aus " , 1
If Y4_modus = 1 Then Lcdat 5 , 64 , "Y4-Ein " , 1
If Y4_modus = 2 Then Lcdat 5 , 64 , "Y4-Auto" , 1
If Y4_modus > 2 Then Lcdat 5 , 64 , "Y4- " ; Y4_modus , 1

Lcdat 8 , 96 , "-" ; Chr(237) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 547
If Merker_taster_minus = 1 Then Y4_modus = Y4_modus -1 : Eram_y4_modus = Y4_modus
If Merker_taster_plus = 1 Then Y4_modus = Y4_modus + 1 : Eram_y4_modus = Y4_modus

Return
'-------------------------------------------------------------------------------


Blatt_551:                                                       ' 551 551 551 551 551 551 551 551
Lcdat 1 , 1 , "EXTERNES"

If Tv_modus = 0 Then Lcdat 3 , 1 , "TV-Aus " , 1
If Tv_modus = 1 Then Lcdat 3 , 1 , "TV-Ein " , 1
If Tv_modus = 2 Then Lcdat 3 , 1 , "TV-Auto  6-22:30" , 1
If Tv_modus > 2 Then Lcdat 3 , 1 , "TV- " ; M1_modus , 1

If Lan_modus = 0 Then Lcdat 4 , 1 , "Lan-Aus "
If Lan_modus = 1 Then Lcdat 4 , 1 , "Lan-Ein "
If Lan_modus = 2 Then Lcdat 4 , 1 , "Lan-Auto 6-22:30"
If Lan_modus > 2 Then Lcdat 4 , 1 , "Lan- " ; M2_modus


Lcdat 8 , 96 , "-" ; Chr(237) ; Chr(236) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = 552
If Merker_taster_zurueck = 1 Then Anzeigeseite = 55
If Merker_taster_minus = 1 Then Tv_modus = Tv_modus -1 : Eram_tv_modus = Tv_modus
If Merker_taster_plus = 1 Then Tv_modus = Tv_modus + 1 : Eram_tv_modus = Tv_modus

Return
'-------------------------------------------------------------------------------


Blatt_552:                                                       ' 552 552 552 552 552 552 552 552
Lcdat 1 , 1 , "EXTERNES"

If Tv_modus = 0 Then Lcdat 3 , 1 , "TV-Aus "
If Tv_modus = 1 Then Lcdat 3 , 1 , "TV-Ein "
If Tv_modus = 2 Then Lcdat 3 , 1 , "TV-Auto  6-22:30"
If Tv_modus > 2 Then Lcdat 3 , 1 , "TV- " ; Tv_modus

If Lan_modus = 0 Then Lcdat 4 , 1 , "Lan-Aus " , 1
If Lan_modus = 1 Then Lcdat 4 , 1 , "Lan-Ein " , 1
If Lan_modus = 2 Then Lcdat 4 , 1 , "Lan-Auto 6-22:30 " , 1
If Lan_modus > 2 Then Lcdat 4 , 1 , "Lan- " ; Lan_modus , 1


Lcdat 8 , 96 , "-" ; Chr(237) ; "+"
If Merker_taster_enter = 1 Then Anzeigeseite = Anzeigeseite
If Merker_taster_zurueck = 1 Then Anzeigeseite = 55
If Merker_taster_minus = 1 Then Lan_modus = Lan_modus -1 : Eram_lan_modus = Lan_modus
If Merker_taster_plus = 1 Then Lan_modus = Lan_modus + 1 : Eram_lan_modus = Lan_modus

Return
'-------------------------------------------------------------------------------






Blaetter_ende:

' ******************************************************************************

'Reset Watchdog                               ' Zurücksetzen des Wachtdog Zählers; (Nach Ablau des Zählers wird reset ausgelöst)

' ******************************************************************************

Loop
End


' ******************************************************************************
' ******************************************************************************
Pufferspeicher:
$bgf "Pufferspeicher.bgf"
Wasserspeicher:
$bgf "Wasserspeicher.bgf"

Solar_boiler:
$bgf "Solarboiler_o_Sonne.bgf"
Solar_boiler_laden:
$bgf "Solarboiler_Sonne.bgf"
Solar_puffer:
$bgf "Solarpuffer_o_Sonne.bgf"
Solar_puffer_laden:
$bgf "Solarpuffer_Sonne.bgf"

Solar_nurboiler:
$bgf "Solar_nur_boiler.bgf"
Solar_nurboiler_laden:
$bgf "Solar_nur_boiler_Sonne.bgf "
Solar_aus:
$bgf "Solar_ausgeschaltet.bgf"                                   ' "Solar_aus.bgf"

Heizkreis:
$bgf "Heizkoerper.bgf"
Brauchwasserladung:
$bgf "Brauchwasser.bgf"
Sonne:
$bgf "Sonne.bgf"
Tagabschaltung:
$bgf "Tagabschaltung.bgf"
Nachtabschaltung:
$bgf "Nachtabschaltung.bgf"
Service:
$bgf "Service.bgf"

Leer:
$bgf "leer.bgf"