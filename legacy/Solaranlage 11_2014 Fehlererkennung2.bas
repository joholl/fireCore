
'  '******************************************************
'Projekt:           Steuerung Solaranlage
'                   mit externem Relaimodul

'
' 30.08.2014
'
'======================================================


$prog &HFF , &HE4 , &HD9  ' Programmierung der Lock & Fusebits


'System-Einstellungen    ******************************************************************
$regfile "m32adef.dat"
'Angabe der Taktfrequenz (8Mhz)
$crystal = 8000000                                               '        ==> Achtung Fuse Bits auf interne 8 MHz einstellen





'Konfigurationen  ***************************************************************************



'------------[LCD 4x16 Config]--------------------------------------------------
Config Lcd = 16 * 4
Config Lcdpin = Pin , Db4 = Portb.3 , Db5 = Portb.2 , Db6 = Portb.1 , Db7 = Portb.0 , E = Portb.4 , Rs = Portb.5
Initlcd

' Deflcdchar 0 , 4 , 21 , 14 , 27 , 14 , 21 , 4 , 32       ' Sonne
Deflcdchar 1 , 24 , 24 , 1 , 3 , 6 , 12 , 32 , 4                 ' Solaranlage (Boiler)
Deflcdchar 2 , 4 , 14 , 21 , 4 , 4 , 4 , 4 , 32                  ' LCD-Zeichen       Pfeil hoch
Deflcdchar 3 , 4 , 4 , 4 , 4 , 21 , 14 , 4 , 32                  ' LCD-Zeichen       Pfeil runter
' Deflcdchar 4 , 14 , 4 , 30 , 1 , 1 , 32 , 1 , 32       ' Brauchwasser (Wasserhahn)
' Deflcdchar 5 , 10 , 30 , 10 , 10 , 10 , 30 , 10 , 32       ' Heizkörper
Deflcdchar 6 , 10 , 10 , 14 , 4 , 4 , 14 , 10 , 10               ' LCD Zeichen Schlüssel
Deflcdchar 7 , 24 , 24 , 1 , 3 , 6 , 12 , 32 , 21                ' Solaranlage  (Puffer)
' LCD chr(223) '223 = binär 11011111     soll Grad Zeichen sein

Deflcdchar 0 , 32 , 1 , 3 , 6 , 12 , 24 , 32 , 24                ' Solar Boiler
Deflcdchar 1 , 24 , 25 , 3 , 6 , 12 , 24 , 32 , 24               ' Solar Bioler Sonne
Deflcdchar 2 , 32 , 1 , 3 , 6 , 12 , 27 , 3 , 3                  ' Solar Puffer
Deflcdchar 3 , 24 , 25 , 3 , 6 , 12 , 27 , 3 , 3                 ' Solar Puffer Sonne
Deflcdchar 4 , 32 , 1 , 3 , 6 , 12 , 24 , 32 , 31                ' Solar NUR Boiler
Deflcdchar 5 , 24 , 25 , 3 , 6 , 12 , 24 , 32 , 31               ' Solar NUR Boiler Sonne

Deflcdchar 6 , 10 , 10 , 14 , 4 , 4 , 14 , 10 , 10               ' Service (Schlüssel)
Deflcdchar 7 , 32 , 1 , 3 , 6 , 12 , 24 , 32 , 32                ' Solar AUS


 'Konfiguration der I/O-Ports´s

Config 1wire = Porta.6                                           'use this pin     DS1820  (brauner 1wire Draht)

'------------[Tasten Config]--------------------------------------------------
Config Pinc.0 = Input                                            ' Taster Anzeige " Blätter + "
Config Pinc.1 = Input                                            ' Taster Anzeige " Blätter - "
Config Pinc.2 = Input                                            ' Taster Anzeige " - "
Config Pinc.3 = Input                                            ' Taster Anzeige " + "
Portc = &HFF                                                     ' Taster Pull up
Config Debounce = 10


Config Pina.7 = Input                                            ' Freigabe 1-wire Bus

'------------[AD-Wandler] --------------------------------------------------
'Konfiguration der Analogeingänge
Config Adc = Single , Prescaler = Auto , Reference = Avcc





Const Skiprom = &HCC                                             ' Überspringe Rom kommando
Const Read_rom = &H33                                            ' Lese Rom
Const Matchrom = &H55                                            'Baustein auswählen
Const Convertt = &H44                                            ' Start Temperaturmessung
Const Read_ram = &HBE                                            'Lese Scratchpad Ram
Const Copy_ram = &H48                                            ' Schreibe Scratch pad Ram
Const Recall_ee = &HB8                                           ' Kopiere EEProm nach Ram
Const Read_power = &HB4                                          ' Abrage Spannung nur DS1820

Dim Rom_2(8) As Byte
Rom_2(1) = 16 : Rom_2(2) = 145 : Rom_2(3) = 33 : Rom_2(4) = 41 : Rom_2(5) = 2 : Rom_2(6) = 8 : Rom_2(7) = 0 : Rom_2(8) = 146       'Adresse  Solarpanel 6 oben  (real Panel2)

Dim Rom_3(8) As Byte
Rom_3(1) = 16 : Rom_3(2) = 115 : Rom_3(3) = 132 : Rom_3(4) = 29 : Rom_3(5) = 2 : Rom_3(6) = 8 : Rom_3(7) = 0 : Rom_3(8) = 114       'Adresse  Boiler2 (mitte)


Dim Rom_11(8) As Byte
Rom_11(1) = 16 : Rom_11(2) = 118 : Rom_11(3) = 156 : Rom_11(4) = 227 : Rom_11(5) = 1 : Rom_11(6) = 8 : Rom_11(7) = 0 : Rom_11(8) = 91       'Adresse Solarrücklauf in PU1-3


Dim Rom_122(8) As Byte
 Rom_122(1) = 41 : Rom_122(2) = 139 : Rom_122(3) = 101 : Rom_122(4) = 8 : Rom_122(5) = 0 : Rom_122(6) = 0 : Rom_122(7) = 0 : Rom_122(8) = 238       '8xIO  chip 2.1 DCF77 Empfänger

Dim Rom_123(8) As Byte
Rom_123(1) = 41 : Rom_123(2) = 229 : Rom_123(3) = 96 : Rom_123(4) = 8 : Rom_123(5) = 0 : Rom_123(6) = 0 : Rom_123(7) = 0 : Rom_123(8) = 236       '8xIO  chip 2.3   Relais für  Solaranlage




Dim Solar_panel_1 As Integer
Dim Solar_panel_2 As Integer
Dim Solar_panel_3 As Integer
Dim Solar_panel_4 As Integer
Dim Solar_panel_5 As Integer
Dim Solar_panel_6 As Integer
Dim Solar_panel_7 As Integer
Dim Solar_panel_temp As Integer

Dim Pu11_temp As Integer
Dim Pu12_temp As Integer
Dim Pu13_temp As Integer
Dim Pu14_temp As Integer
Dim Pu15_temp As Integer
Dim Pu21_temp As Integer
Dim Pu22_temp As Integer
Dim Pu23_temp As Integer
Dim Pu24_temp As Integer
Dim Pu25_temp As Integer
Dim Pu31_temp As Integer
Dim Pu32_temp As Integer
Dim Pu33_temp As Integer
Dim Puffer_temp As Integer

Dim Boi2_temp As Integer
Dim Boi_temp As Integer

Dim Hot_system As Bit
Dim Solar_boiler_laden As Bit
Dim Solar_betrieb As Bit
Dim Solar_energie_vorhanden As Bit


Dim Dcf_byte_in As Byte
' Dcf_byte.0 Eingang = ' Täglich,  von 22:00-06:00 wird 1 ausgegeben
' Dcf_byte.1 Eingang = ' Sonntags, von 06:00-07:00 wird 1 ausgegeben
' Dcf_byte.2 Ausgang = 0 ==> Rundfunk abschalten
' Dcf_byte.3 Ausgang = 0 ==> Internet abschalten


Dim Solar_relais_byte_in As Byte : Solar_relais_byte_in = 255
' Bit_0 = M4 Solarpumpe               ( Ausgang low = Pumpe an)
' Bit_1 = Y4 Solarventil              ( Ausgang low = Ventil an = Puffer laden)
' Bit_2 = Zustand Boiler/Puffer laden ( Ausgang low = Puffer; high = Boiler)
' Bit_3 = Zustand Hot System          ( Ausganh high = System is Hot)
' Bit_4 = 1-wire Fehler                ( Ausganh high = Fehler>0)
' Bit_6 = Nur Boilerladung            ( Eingang; low = Es wird nur der Boiler geladen )
' Bit_7 = Solarsteuerung aktiv        ( Eingang; Ausgänge werden nur geschaltet, wenn Bit7 high ist)


Dim Solar_relais_byte_out As Byte

M4_inv_solarpumpe Alias Solar_relais_byte_out.0                  '      Low = Relais Kontakt schließt ==> Solar-Pumpe läuft
Y4_inv_puffer_laden Alias Solar_relais_byte_out.1                ' Low = Relais Kontakt schließt ==> Solarventil auf Boilerladung
Solar_relais_byte_out = 255


Dim Merker_zeit_synchro As Bit
Dim Zeit_ist_aktuell As Bit

Dim Taster_gedrueckt As Bit
Dim Anzeige_ruecksprungzeit As Byte
Dim Bus_abfragezaehler As Byte
Dim Anzeige_sec_alt As Byte
Dim Bus_sec_alt As Byte


Dim Temp1 As Integer
Dim Temp2 As Integer
Dim Bytetemp As Byte
Dim Bytetemp2 As Byte
Dim Integer_temp1 As Integer
Dim Integer_temp2 As Integer
Dim Temp_long As Long

Dim Adc_wert As Word

Dim I As Byte
Dim Ram(9) As Byte
Dim Anzeigeseite As Byte
Dim Bus_abfrage_anzeige As Bit
Dim 1wire_fehler As String *14




'------------[Initialisierung der internen Bascom Softclock Uhrenroutine]-------
Enable Interrupts

'[now init the clock]
Config Date = Dmy , Separator = .                                ' Datumsformat definieren z.B. 31.12.10

Config Clock = Soft                                              'Initialisiert die Bascom eigene Uhr Routine
' Achtung!!! Funktioniert nur, wenn an TOSC1 und TOSC2 ein 32.768 MHz Uhrenquarz angeschlossen ist.
'The above statement will bind in an ISR so you can not use the TIMER anymore!


Time$ = "10:00:00"                                               ' Vorauswahl des Zeitwertes


'---------------------------------------------------------------------------------------------------------------------------





' +++++++++++++++++++++ Eram Werte definieren und laden +++++++++++++++++++++++++++++++++++++++

Dim Eram_dummy As Eram Byte                                      ' erstes Byte sollte als dummy stehen, da bei reset gelöscht wird
Dim Eram_programmierstart As Eram Byte
Dim Eram_solar_boiler_min As Eram Integer                        ' Bit wird beim ersten Start nach der Programmierung gesetzt, um die Eramwerte zu laden
Dim Eram_solar_boiler_max As Eram Integer
Dim Eram_solar_diff_temp_ein As Eram Integer
Dim Eram_solar_diff_temp_aus As Eram Integer
Dim Eram_solar_hot_temp As Eram Integer
Dim Eram_m4_modus As Eram Integer
Dim Eram_y4_modus As Eram Integer
Dim Eram_bus_abfragezeit As Eram Byte
Dim Eram_sensortyp As Eram Byte                                  ' 1 = PT1000; 2 = 1wire

Dim Programmierstart As Byte
Dim Solar_boiler_min As Integer
Dim Solar_boiler_max As Integer
Dim Solar_diff_temp_ein As Integer
Dim Solar_diff_temp_aus As Integer
Dim Solar_hot_temp As Integer
Dim M4_modus As Integer
Dim Y4_modus As Integer
Dim Bus_abfragezeit As Byte
Dim Sensortyp As Byte                                            ' 1 = PT1000; 2 = 1wire


Programmierstart = Eram_programmierstart
' Programmierstart = 255
If Programmierstart = 255 Then                                   ' ERAM Werte werden nach Programmierung definiert

Temp1 = 55
Eram_solar_boiler_min = Temp1

Temp1 = 65
Eram_solar_boiler_max = Temp1

Temp1 = 10
Eram_solar_diff_temp_ein = Temp1

Temp1 = 3
Eram_solar_diff_temp_aus = Temp1

Temp1 = 92
Eram_solar_hot_temp = Temp1

Temp1 = 2
Eram_m4_modus = Temp1                                            ' 2 = AUTO

Temp1 = 2
Eram_y4_modus = Temp1                                            ' 2 = AUTO

Bytetemp = 5
Eram_bus_abfragezeit = Bytetemp                                  ' Zeit wie oft Bus abgefragt wird

Bytetemp = 1
Eram_sensortyp = Bytetemp                                        ' 1 = PT1000; 2 = 1wire

Programmierstart = Programmierstart + 1
Eram_programmierstart = Programmierstart
End If



Solar_boiler_min = Eram_solar_boiler_min
Solar_boiler_max = Eram_solar_boiler_max
Solar_diff_temp_ein = Eram_solar_diff_temp_ein
Solar_diff_temp_aus = Eram_solar_diff_temp_aus
Solar_hot_temp = Eram_solar_hot_temp
M4_modus = Eram_m4_modus
Y4_modus = Eram_y4_modus
Bus_abfragezeit = Eram_bus_abfragezeit
Sensortyp = Eram_sensortyp

' Goto Vorspann


' ----------- Solar Relais Ausgangsbyte FF schreiben ----------------------------------------

Ausgang_loeschen:
Config Pina.7 = Input
       If Pina.7 = 0 Then                                        ' Bus ist belegt
       Bus_abfrage_anzeige = 0
       Goto Ausgang_loeschen
       Else                                                      ' Bus ist frei
       Bus_abfrage_anzeige = 1
       Config Porta.7 = Output
       Porta.7 = 0
End If
' -----------
1wverify Rom_123(1)                                              ' Rom_1 represents the DS2408 ROM address
If Err = 1 Then
   1wire_fehler = "Fehler Rel    "

   Else
   1wwrite &HCC                                                  ' write Conditional Search Register
   1wwrite &H8D                                                  ' Adresse 008D
   1wwrite &H00
   1wwrite &H04                                                  ' ROS = 1   (Sollte immer mitgeschrieben werden, da bei Stromausfall bit verloren geht)
   1wreset

   1wverify Rom_123(1)
   If Err = 1 Then
      1wire_fehler = "Fehler Rel    "

      Else
      Bytetemp = 255                                             ' Alle Ausgänge aus (inkl. die der Eingänge)
      1wwrite &H5A                                               ' Pio_access_write
      1wwrite Bytetemp                                           '8_out                            ' Ausgangsbyte senden
      Toggle Bytetemp
      1wwrite Bytetemp                                           ' Invertiertes Byte zur Bestätigung senden
      1wreset
   End If
End If

'------------ Anzeige Vorspann ------------------------------------------------------
Vorspann:


Cursor Off
Cls
Lcd "Solarsteuerung"                                             'Startmeldung:
Locate 2 , 1
Lcd "V11"
Locate 3 , 1
Lcd "15.11.2014"
Locate 4 , 1
Lcd "Sep. Fuehler"
Wait 3




'------------[Watchdog Config]-----------------------------------------------------

Config Watchdog = 2048                                           'Konfiguration des Watchdog mit reset after ca. 2048 mSec
Start Watchdog

Cls
Cursor Off

Do
Start:




' ******************************************************************************
' ---------------------  Bus nur Abfragen, wenn Anzeigeseite = 0  --------------
 If Anzeigeseite > 0 Then Goto 1wire_lesen__ende


 ' ---------------------  Bus nur Abfragen, wenn Bus_abfragezaehler = 0  --------------
 If Bus_abfragezaehler > 0 Then
    Bus_abfrage_anzeige = 0

    Goto 1wire_lesen__ende
    End If


' ******************************************************************************
' ********************** Prüfen, ob Bus frei ist *******************************

Config Pina.7 = Input
If Pina.7 = 0 Then                                               ' Bus ist belegt
Bus_abfrage_anzeige = 0
Goto Logik

Else                                                             ' Bus ist frei
Bus_abfrage_anzeige = 1

Config Porta.7 = Output
Porta.7 = 0

End If


' ******************************************************************************
' ********************** Messung Starten ***************************************************

1wire_fehler = "              "                                                 ' Fehler von vorheriger Messung löschen



1wreset                                                          ' Bus reset
    If Err = 1 Then                                              ' Bus auf Fehler prüfen

   1wire_fehler = "Busfehler     "
   Goto 1wire_lesen__ende

   Y4_inv_puffer_laden = 1                                       ' Bei Busfehler Relais abschalten
   M4_inv_solarpumpe = 1

   End If

1wwrite Skiprom                                                  ' Rom Adressierung überspringen --> alle ansprechen
1wwrite Convertt                                                 ' Start Temperaturmessung
Waitms 500

 ' ********************* Messwert auslesen und verarbeiten ********************************************************************



  1wverify Rom_2(1)                                              ' Den gewünschten Sensor auswählen
     If err = 1 then
     1wire_fehler = "Fehler Sol6   "
     else
      1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
      Ram(1) = 1wread(9)
      If Ram(9) = Crc8(ram(1) , 8) Then
      Solar_panel_6 = Makeint(ram(1) , Ram(2))
      Solar_panel_6 = Solar_panel_6 / 2                              ' AusLesewert °C berechnen
        Else
        1wire_fehler = "Fehler Sol6   "
        Solar_panel_6 = 0
      End If
    End If



 ' -----------------------------------------------------------------------------

  1wverify Rom_3(1)                                              ' Den gewünschten Sensor auswählen
   If err = 1 then
   1wire_fehler = "Fehler Boi2   "
   Else
   1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
   Ram(1) = 1wread(9)
      If Ram(9) = Crc8(ram(1) , 8) Then
      Boi2_temp = Makeint(ram(1) , Ram(2))
      Boi2_temp = Boi2_temp / 2                                      ' AusLesewert °C berechnen
      Else
      1wire_fehler = "Fehler Boi2   "
      Boi2_temp = 0
      End If
   End If

 ' -----------------------------------------------------------------------------



  ' -----------------------------------------------------------------------------

  ' -----------------------------------------------------------------------------

  1wverify Rom_11(1)                                             ' Den gewünschten Sensor auswählen
  If err = 1 then
  1wire_fehler = "Fehler PU13   "
  Else
  1wwrite Read_ram                                                ' Kommando READ SCRATCHPAD
  Ram(1) = 1wread(9)
   If Ram(9) = Crc8(ram(1) , 8) Then
   Pu13_temp = Makeint(ram(1) , Ram(2))
   Pu13_temp = Pu13_temp / 2                                      ' AusLesewert °C berechnen
   Else
   1wire_fehler = "Fehler PU13   "
   Pu13_temp = 0
   End If
  End IF
  ' -----------------------------------------------------------------------------


' -----------------------------------------------------------------------------



 '   ================== DCF77 Pin-Status Reading 8xIO===========================

 1wreset
 1wverify Rom_122(1)                                             ' Den gewünschten Sensor auswählen
  If Err = 1 Then
    1wire_fehler = "Fehler DCF77  "
    Else

1wwrite &HF5                                                     ' Pio Access Read
   Dcf_byte_in = 1wread(1)
1wreset

 End If
' -----------------------------------------------------------------------------

'   ================== Solarrelais Pin-Status Reading 8xIO===========================

 1wreset
 1wverify Rom_123(1)                                             ' Den gewünschten Sensor auswählen
  If Err = 1 Then
    1wire_fehler = "Fehler Rel    "
    Else

1wwrite &HF5                                                     ' Pio Access Read
   Solar_relais_byte_in = 1wread(1)
1wreset

 End If
' -----------------------------------------------------------------------------

'===============================================================================
' ======================= Output write 8xIO --> Solarrelais =================================
'===============================================================================

' Bit_0 = M4 Solarpumpe               ( Ausgang low = Pumpe an)
' Bit_1 = Y4 Solarventil              ( Ausgang low = Ventil an = Puffer laden)
' Bit_2 = Zustand Boiler/Puffer laden ( Ausgang low = Puffer; high = Boiler)
' Bit_3 = Zustand Hot System          ( Ausganh high = System is Hot)
' Bit_4 = 1-wire Fehler                ( Ausganh high = Fehler>0)
' Bit_5 =
' Bit_6 = Nur Boilerladung            ( Eingang; low = Es wird nur der Boiler geladen )
' Bit_7 = Solarsteuerung aktiv        ( Eingang; Ausgänge werden nur geschaltet, wenn Bit7 high ist)


 ' ---------------------------  Ausgänge maskieren ----------------------------
' Bytetemp = Solar_relais_byte_in
Bytetemp.0 = M4_inv_solarpumpe
Bytetemp.1 = Y4_inv_puffer_laden
Bytetemp.2 = Solar_boiler_laden
Bytetemp.3 = Hot_system
If 1wire_fehler > "" Then Bytetemp.4 = 1
If 1wire_fehler = "" Then Bytetemp.4 = 0

Bytetemp.5 = 1                                                   ' Achtung Eingangsbits müssen 1 sein
Bytetemp.6 = 1                                                   ' Achtung Eingangsbits müssen 1 sein
Bytetemp.7 = 1                                                   ' Achtung Eingangsbits müssen 1 sein

Solar_relais_byte_out = Bytetemp
' ---------------------------

   1wverify Rom_123(1)                                           ' Rom_1 represents the DS2408 ROM address
   If Err = 1 Then
      1wire_fehler = "Fehler Rel    "
      Else
      1wwrite &HCC                                               ' write Conditional Search Register
      1wwrite &H8D                                               ' Adresse 008D
      1wwrite &H00
      1wwrite &H04                                               ' ROS = 1   (Sollte immer mitgeschrieben werden, da bei Stromausfall bit verloren geht)
      1wreset

      1wverify Rom_123(1)
      If Err = 1 Then
         1wire_fehler = "Fehler Rel    "
         Else
'         Bytetemp = Bytetemp
         1wwrite &H5A                                            ' Pio_access_write
         1wwrite Bytetemp                                        '8_out                            ' Ausgangsbyte senden
         Toggle Bytetemp
         1wwrite Bytetemp                                        ' Invertiertes Byte zur Bestätigung senden
         1wreset
      End If
   End If

' ------------------------------------------------------------------------------


' ******************************************************************************
' ********************** Bus wieder freigeben ***************************************************
Bus_freigeben:
Bus_abfragezaehler = Bus_abfragezeit

1wire_lesen__ende:

Porta.7 = 1
Config Porta.7 = Input



' ******************************************************************************
' ********************** Analog Messung ****************************************

Bytetemp = Bus_abfragezeit
Bytetemp = Bytetemp / 2


' If Bus_abfragezaehler = Bytetemp Then                           'Temperaturabfrage nur wenn 1sec vor Busabrage (Temperaturverzerrungen vermeiden)

'Anschaltung der Analogwert-Verarbeitung
Start Adc
Waitms 100

' Analogwert von Port A.0 lesen
Adc_wert = Getadc(0)                                             ' Analogwerte von 0 bis 1024 werden ermittelt
Temp_long = Adc_wert

Stop Adc


' Testschalter
' ------------
' 1    842 Ohm = -40°C
' 0   1800 Ohm = 212°C
' 1   1000 Ohm =   0°C




' Gemessen ADC_Wert=271 bei 3°C; ADC_Wert=428 bei 88°C
' Steigung = (88°C - 3°C) / (428 - 271) = 0,541401273
' Niveau =  Y=(Steigung x X) + Niveau    => -143.719745221


' Berechnung: (AD-Wert*0,54) -143
' ==========



Temp_long = Temp_long * 54140
Temp_long = Temp_long / 100000
Temp_long = Temp_long - 144
Solar_panel_7 = Temp_long


' End If




' ------------------------------------------------------------------------------









Logik:
' ********************* Schaltlogik Solaranlage Neu********************************
' ******************************************************************************


'§§§§§§§§§§§§§§§§§ Für Testzwecke ohne Busverbindungg §§§§§§§§§§§§§§§§§§§§§§§§§§§

'(
Solar_panel_6 = 100
Pu14_temp = 20
Boi2_temp = 60
Solar_relais_byte_in = &B11100000

' Bit_0 = M4 Solarpumpe               ( Ausgang low = Pumpe an)
' Bit_1 = Y4 Solarventil              ( Ausgang low = Ventil an = Puffer laden)
' Bit_2 = Zustand Boiler/Puffer laden ( Ausgang low = Puffer; high = Boiler)
' Bit_3 = Zustand Hot System          ( Ausganh high = System is Hot)
' Bit_4 = 1-wire Fehler                ( Ausganh high = Fehler>0)
' Bit_6 = Nur Boilerladung            ( Eingang; low = Es wird nur der Boiler geladen )
' Bit_7 = Solarsteuerung aktiv        ( Eingang; Ausgänge werden nur geschaltet, wenn Bit7 high ist)

')

'§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§



' Für Logik Herangezogene Werte
' -----------------------------

If Sensortyp = 1 Then Solar_panel_temp = Solar_panel_7           ' Verwendete Solarpaneltemperatur ==> Solar_panel_7 (PT1000)
If Sensortyp = 2 Then Solar_panel_temp = Solar_panel_6           ' Verwendete Solarpaneltemperatur ==> Solar_panel_6 (1-wire)

  Puffer_temp = Pu13_temp                                        ' Verwendete Puffertemperatur ==> Pu13_temp
  Boi_temp = Boi2_temp                                           ' Verwendete Boilertemperatur ==> Boi2_temp
             '



' ==================== Zustand:    System ist Heiß ============================= (Hot_system = 1)

  Integer_temp2 = Solar_hot_temp                                 ' Einstellwert füt Hotabschaltung laden  (z.B.92°C)

  If Puffer_temp >= Integer_temp2 Or Boi_temp >= Integer_temp2 Then Hot_system = 1 Else Hot_system = 0       ' Alles heiß => Endabschaltung



' ==================== Zustand:   Solare Boiler / Puffer Ladung ================ ( Solar_boiler_laden = 1 für Boiler laden)

If Y4_modus = 0 Then Solar_boiler_laden = 1
If Y4_modus = 1 Then Solar_boiler_laden = 0

If Y4_modus = 2 Then
   If Solar_relais_byte_in.6 = 0 Then                            ' ( 8IO Eingangsbyte Eingang6; low = Es wird nur der Boiler geladen )
   Solar_boiler_laden = 1                                        ' Nur Boiler laden (von extern)

   Else
   If Boi_temp < Solar_boiler_min Then Solar_boiler_laden = 1    ' Umschalten auf Boiler laden
   If Boi_temp > Solar_boiler_max Then Solar_boiler_laden = 0    ' Zurückschalten auf Puffer laden
   End If
End If


' ==================== Zustand:   Solar Energie vorhanden =====

  If Solar_boiler_laden = 1 Then                                 'Fall 1: Termperaturwerte für Boiler Betrieb
     Integer_temp1 = Boi_temp + Solar_diff_temp_ein
     If Solar_panel_temp > Integer_temp1 Then Solar_energie_vorhanden = 1       ' Solar_energie_vorhanden = 1, wenn Rücklauf + Differenztemp erreicht

     Integer_temp1 = Boi_temp + Solar_diff_temp_aus
     If Solar_panel_temp < Integer_temp1 Then Solar_energie_vorhanden = 0       ' Solar_energie_vorhanden = 0, wenn Rücklauf + Differenz unterschritten
  End If


  If Solar_boiler_laden = 0 Then                                 'Fall 2: Termperaturwerte für Puffer Betrieb
     Integer_temp1 = Puffer_temp + Solar_diff_temp_ein
     If Solar_panel_temp > Integer_temp1 Then Solar_energie_vorhanden = 1       ' Solar_energie_vorhanden = 1, wenn Rücklauf + Differenztemp erreicht

     Integer_temp1 = Puffer_temp + Solar_diff_temp_aus
     If Solar_panel_temp < Integer_temp1 Then Solar_energie_vorhanden = 0       ' Solar_energie_vorhanden = 0, wenn Rücklauf + Differenz unterschritten
  End If




' ==================== Zustand:   Solarbetrieb ====== (Solar_betrieb = 1 wenn Sonne scheint + dT überschritten)

If Solar_relais_byte_in.6 = 1 Then Solar_betrieb = Solar_energie_vorhanden       'Im Normalbetrieb läuft Pumpe, wenn Energie vorhanden

If Solar_relais_byte_in.6 = 0 Then                               ' Im NUR BOILER Betrieb läuft Pumpe nur, wenn Boilertemp noch nicht erreicht ist
   If Boi_temp > Solar_boiler_max Then
   Solar_betrieb = 0
   Else
   Solar_betrieb = Solar_energie_vorhanden
   End If
End If






' ------------------- Ausgänge setzen:  Y4 Solarventil Umschaltung -------------
Logik_umschaltung:

  If Hot_system = 0 Then

     If Y4_modus = 0 Then Y4_inv_puffer_laden = 1                ' Modus AUS
     If Y4_modus = 1 Then Y4_inv_puffer_laden = 0                ' Modus EIN

     If Y4_modus = 2 Then                                        ' Modus AUTO
        If Solar_betrieb = 1 And Solar_boiler_laden = 0 Then Y4_inv_puffer_laden = 0       ' Umschalten auf Puffer laden ( Ausgang low = Ventil an = Puffer laden)
        If Solar_betrieb = 0 Or Solar_boiler_laden = 1 Then Y4_inv_puffer_laden = 1       ' Stromlos auf Boiler laden
     End If


  Else
  Y4_inv_puffer_laden = 1                                        ' Alles heiß => Endabschaltung
  End If



' -------------------- Ausgänge setzen:  M4 Solar Pumpe ------------------------


  If Hot_system = 0 Then


     If M4_modus = 0 Then M4_inv_solarpumpe = 1                  ' Modus AUS
     If M4_modus = 1 Then M4_inv_solarpumpe = 0                  ' Modus EIN

     If M4_modus = 2 Then                                        ' Modus AUTO
        If Solar_relais_byte_in.7 = 1 Then                       ' ' Pumpenansteuerung erfolgt nur, wenn Freigabe extern von Solar-byte.7 da ist
           If Solar_betrieb = 1 Then M4_inv_solarpumpe = 0
           If Solar_betrieb = 0 Then M4_inv_solarpumpe = 1
           Else
           M4_inv_solarpumpe = 1
        End If
     End If

  Else
  M4_inv_solarpumpe = 1                                          ' Alles heiß => Endabschaltung
  End If
' ------------------------------------------------------------------------------
' ------------------------------------------------------------------------------
' ------------------------------------------------------------------------------



' ---------------------------  Zeit synchronisieren ----------------------------

' ( von 22:00-06:00 wird von DCF77 A.0=1 ausgegeben )
If Dcf_byte_in.0 = 0 And Merker_zeit_synchro = 1 Then Time$ = "06:00:00" : Merker_zeit_synchro = 0 : Zeit_ist_aktuell = 1       ' Merker_zeit_synchro = 0 verhindert weitere synchronisation

If Dcf_byte_in.0 = 1 Then Merker_zeit_synchro = 1                ' Merker_zeit_synchro = 1 wird wieder scharf geschaltet bis zur nächsten synchronisation (A.0= High=>Low)
' ------------------------------------------------------------------------------


' --------------  Zeitroutine Anzeigeseite = 0 ohne Tastendruck ----------------

' Hier wird die Anzeige bei nicht Betätigung zurück auf Startseite gestellt
If Anzeigeseite > 0 Then

   If Taster_gedrueckt = 1 Then Anzeige_ruecksprungzeit = 60 : Taster_gedrueckt = 0
   If _sec <> Anzeige_sec_alt Then Anzeige_ruecksprungzeit = Anzeige_ruecksprungzeit - 1 : Anzeige_sec_alt = _sec
      If Anzeige_ruecksprungzeit = 0 Then
      Anzeigeseite = 0
      Cls
      End If
End If
' ------------------------------------------------------------------------------


' --------------  Zeitroutine Busabfrage ---------------------------------------
If Bus_abfragezaehler > 0 Then
   If _sec <> Bus_sec_alt Then Bus_abfragezaehler = Bus_abfragezaehler - 1 : Bus_sec_alt = _sec
End If
' ------------------------------------------------------------------------------





' *************************** Anzeige *************************************************************************************************
' **************************************************************************************************************************************
Anzeige:

 Debounce Pinc.0 , 0 , Inc_anzeigeseite                          ' Impuls von Taster erkennen
 Debounce Pinc.1 , 0 , Dec_anzeigeseite                          ' Impuls von Taster erkennen
 Goto Weiter00

 Inc_anzeigeseite:
                    If Anzeigeseite = 11 Then                    ' Anzeige wechseln
                    Anzeigeseite = 0
                    Else
                    Anzeigeseite = Anzeigeseite + 1
                    End If
                    Cls
                    Taster_gedrueckt = 1
                    Goto Weiter00
 Dec_anzeigeseite:
                    If Anzeigeseite = 0 Then                     ' Anzeige wechseln
                    Anzeigeseite = 11
                    Else
                    Anzeigeseite = Anzeigeseite - 1
                    End If
                    Cls
                    Taster_gedrueckt = 1
                    Goto Weiter00

 Weiter00:


'-------------------------------------------------------------------------------

                If Anzeigeseite = 0 Then                         ' Anzeigeseite 0 ausgeben
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
       Lcd "Panel " ; Solar_panel_temp ; Chr(223) ; " "
Locate 2 , 1
       Lcd "Puff  " ; Puffer_temp ; Chr(223) ; " "
Locate 3 , 1
       Lcd "Boil  " ; Boi_temp ; Chr(223) ; " "



Locate 1 , 11
       If M4_inv_solarpumpe = 0 Then Lcd "M4=ON "
       If M4_inv_solarpumpe = 1 Then Lcd "M4=OFF"

Locate 2 , 11
       If Y4_inv_puffer_laden = 0 Then Lcd "Y4=ON "
       If Y4_inv_puffer_laden = 1 Then Lcd "Y4=OFF"



Locate 3 , 11
If Solar_relais_byte_in.7 = 0 Then Lcd Chr(7)                    ' Solar-Steuerung außer Betrieb

If Solar_relais_byte_in.7 = 1 Then                               ' Solar-Steuerung in Betrieb, wenn Solar_relais_byte_in.7 = 1 ist
   If Solar_relais_byte_in.6 = 0 And Solar_betrieb = 0 Then Lcd Chr(4)       ' Solaranlage Nur_Boiler
   If Solar_relais_byte_in.6 = 0 And Solar_betrieb = 1 Then Lcd Chr(5)       ' Solaranlage Nur_Boiler + Sonne

   If Solar_relais_byte_in.6 = 1 Then
      If Solar_betrieb = 0 And Solar_boiler_laden = 1 Then Lcd Chr(0)       ' Solaranlage Boiler
      If Solar_betrieb = 1 And Solar_boiler_laden = 1 Then Lcd Chr(1)       ' Solaranlage Boiler + Sonne
      If Solar_betrieb = 0 And Solar_boiler_laden = 0 Then Lcd Chr(2)       ' Solaranlage Puffer
      If Solar_betrieb = 1 And Solar_boiler_laden = 0 Then Lcd Chr(3)       ' Solaranlage Puffer + Sonne
   End If
End If

'§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§


' Nur zu Testzwecken
Locate 3 , 13
 Lcd Adc_wert ; " "


'§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§



Locate 4 , 12
       If Hot_system = 1 Then Lcd "Hot"



Locate 4 , 1
   If 1wire_fehler = "              " Then
   Lcd Time$ ; "      "
   else
   Lcd  1wire_fehler
   Endif

Locate 4 , 15
       If Bus_abfrage_anzeige = 0 Then Lcd "."
       If Bus_abfrage_anzeige = 1 Then
          Lcd ">"
          Waitms 500
       End If


End If

'-------------------------------------------------------------------------------

                 If Anzeigeseite = 1 Then
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
Lcd "Panelwerte"

Locate 2 , 1
Lcd Solar_panel_1 ; Chr(223)
Locate 2 , 5
Lcd Solar_panel_2 ; Chr(223)
Locate 2 , 10
Lcd Solar_panel_3 ; Chr(223)
Locate 3 , 1
Lcd Solar_panel_4 ; Chr(223)
Locate 3 , 5
Lcd Solar_panel_5 ; Chr(223)
Locate 3 , 10
Lcd Solar_panel_6 ; Chr(223)
Locate 4 , 1
Lcd Solar_panel_7 ; Chr(223)

Locate 4 , 8
Lcd Adc_wert ; " "


End If

'-------------------------------------------------------------------------------

If Anzeigeseite = 2 Then
Locate 4 , 16
       Lcd Anzeigeseite

Locate 1 , 1
Lcd "P " ; Pu11_temp ; "  P " ; Pu21_temp ; "  P " ; Pu31_temp
Locate 2 , 1
Lcd "U " ; Pu12_temp ; "  U " ; Pu22_temp ; "  U " ; Pu32_temp
Locate 3 , 1
Lcd "F " ; Pu13_temp ; "  F " ; Pu23_temp ; "  F " ; Pu33_temp
Locate 4 , 1
Lcd "1 " ; Pu14_temp ; "  2 " ; Pu24_temp ; "  3 "

End If

'-------------------------------------------------------------------------------

                 If Anzeigeseite = 3 Then
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
Lcd "Einstellmodus"                                              ' Boiler min. einstellen
Locate 3 , 1
Lcd "Boiler min. " ; Solar_boiler_min ; Chr(223) ;
Debounce Pinc.2 , 0 , Dec_boiler_min                             ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_boiler_min                             ' Impuls von Taster erkennen
                    Goto Weiter1

Dec_boiler_min:
                    Solar_boiler_min = Solar_boiler_min - 1
                    Eram_solar_boiler_min = Solar_boiler_min
                    Taster_gedrueckt = 1
                    Goto Weiter1

Inc_boiler_min:
                    Solar_boiler_min = Solar_boiler_min + 1
                    Eram_solar_boiler_min = Solar_boiler_min
                    Taster_gedrueckt = 1
                    Goto Weiter1

 Weiter1:

Locate 4 , 1
Lcd "(Boi_2)"


End If

'-------------------------------------------------------------------------------

                 If Anzeigeseite = 4 Then
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
Lcd "Einstellmodus"                                              ' Boiler min. einstellen
Locate 3 , 1

Lcd "Boiler max. " ; Solar_boiler_max ; Chr(223) ; " "
Debounce Pinc.2 , 0 , Dec_boiler_max                             ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_boiler_max                             ' Impuls von Taster erkennen
                    Goto Weiter2

Dec_boiler_max:
                    Solar_boiler_max = Solar_boiler_max - 1
                    Eram_solar_boiler_max = Solar_boiler_max
                    Taster_gedrueckt = 1
                    Goto Weiter2

Inc_boiler_max:
                    Solar_boiler_max = Solar_boiler_max + 1
                    Eram_solar_boiler_max = Solar_boiler_max
                    Taster_gedrueckt = 1
                    Goto Weiter2

Weiter2:

Locate 4 , 1
Lcd "(Boi_2)"

End If

'-------------------------------------------------------------------------------

                 If Anzeigeseite = 5 Then
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
Lcd "Einstellmodus"                                              ' Differenztemp ein einstellen
Locate 3 , 1

Lcd "Diff. ein " ; Solar_diff_temp_ein ; Chr(223) ; "    "
Debounce Pinc.2 , 0 , Dec_diff_temp_ein                          ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_diff_temp_ein                          ' Impuls von Taster erkennen
                    Goto Weiter3

Dec_diff_temp_ein:
                    Solar_diff_temp_ein = Solar_diff_temp_ein - 1
                    Eram_solar_diff_temp_ein = Solar_diff_temp_ein
                    Taster_gedrueckt = 1
                    Goto Weiter3

Inc_diff_temp_ein:
                    Solar_diff_temp_ein = Solar_diff_temp_ein + 1
                    Eram_solar_diff_temp_ein = Solar_diff_temp_ein
                    Taster_gedrueckt = 1
                    Goto Weiter3




Weiter3:


End If

'-------------------------------------------------------------------------------


                 If Anzeigeseite = 6 Then
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
Lcd "Einstellmodus"                                              ' Differenztemp aus einstellen
Locate 3 , 1

Lcd "Diff. aus " ; Solar_diff_temp_aus ; Chr(223) ; "    "
Debounce Pinc.2 , 0 , Dec_diff_temp_aus                          ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_diff_temp_aus                          ' Impuls von Taster erkennen
                    Goto Weiter4

Dec_diff_temp_aus:
                    Solar_diff_temp_aus = Solar_diff_temp_aus - 1
                    Eram_solar_diff_temp_aus = Solar_diff_temp_aus
                    Taster_gedrueckt = 1
                    Goto Weiter4

Inc_diff_temp_aus:
                    Solar_diff_temp_aus = Solar_diff_temp_aus + 1
                    Eram_solar_diff_temp_aus = Solar_diff_temp_aus
                    Taster_gedrueckt = 1
                    Goto Weiter4




Weiter4:




End If

'-------------------------------------------------------------------------------


                 If Anzeigeseite = 7 Then
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
Lcd "Einstellmodus"                                              ' Differenztemp aus einstellen
Locate 3 , 1
Lcd "Hot-Aus  " ; Solar_hot_temp ; Chr(223) ; "    "
Locate 4 , 1
Lcd "(PU1-3)"



Debounce Pinc.2 , 0 , Dec_hot_abschaltung                        ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_hot_abschaltung                        ' Impuls von Taster erkennen
                    Goto Weiter5

Dec_hot_abschaltung:
                    Solar_hot_temp = Solar_hot_temp - 1
                    Eram_solar_hot_temp = Solar_hot_temp
                    Taster_gedrueckt = 1
                    Goto Weiter5

Inc_hot_abschaltung:
                    Solar_hot_temp = Solar_hot_temp + 1
                    Eram_solar_hot_temp = Solar_hot_temp
                    Taster_gedrueckt = 1
                    Goto Weiter5




Weiter5:



End If
'-------------------------------------------------------------------------------


                 If Anzeigeseite = 8 Then
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
Lcd "Einstellmodus"                                              ' Differenztemp aus einstellen
Locate 3 , 1
Lcd "Bus Zeit " ; Bus_abfragezeit ; " Sec "
Debounce Pinc.2 , 0 , Dec_bus_abfragezeit                        ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_bus_abfragezeit                        ' Impuls von Taster erkennen
                    Goto Weiter6

Dec_bus_abfragezeit:
                    Bus_abfragezeit = Bus_abfragezeit - 2
                    Eram_bus_abfragezeit = Bus_abfragezeit
                    Taster_gedrueckt = 1
                    Goto Weiter6

Inc_bus_abfragezeit:
                    Bus_abfragezeit = Bus_abfragezeit + 2
                    Eram_bus_abfragezeit = Bus_abfragezeit
                    Taster_gedrueckt = 1
                    Goto Weiter6

Weiter6:

End If


'-------------------------------------------------------------------------------




                 If Anzeigeseite = 9 Then
Locate 4 , 16
Lcd Anzeigeseite

Locate 1 , 1
Lcd "Einstellmodus   "                                           ' Pumpenmodus einstellen


Locate 3 , 1
If M4_modus = 0 Then
Lcd "Pumpe: AUS "
End If
If M4_modus = 1 Then
Lcd "Pumpe: EIN "
End If
If M4_modus = 2 Then
Lcd "Pumpe: AUTO"
End If



Debounce Pinc.2 , 0 , Dec_m4_modus                               ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_m4_modus                               ' Impuls von Taster erkennen
                    Goto Weiter7

Dec_m4_modus:
                    If M4_modus = 0 Then
                    M4_modus = 2
                    Else
                    M4_modus = M4_modus - 1
                    End If
                    Eram_m4_modus = M4_modus
                    Taster_gedrueckt = 1
                    Goto Weiter7

Inc_m4_modus:
                    If M4_modus = 2 Then
                    M4_modus = 0
                    Else
                    M4_modus = M4_modus + 1
                    End If
                    Eram_m4_modus = M4_modus
                    Taster_gedrueckt = 1
                    Goto Weiter7

 Weiter7:




End If

'-------------------------------------------------------------------------------

                 If Anzeigeseite = 10 Then
Locate 4 , 16
Lcd "A"

Locate 1 , 1
Lcd "Einstellmodus"                                              ' Pumpenmodus einstellen


Locate 3 , 1
If Y4_modus = 0 Then
Lcd "Ventil: AUS "
End If
If Y4_modus = 1 Then
Lcd "Ventil: EIN "
End If
If Y4_modus = 2 Then
Lcd "Ventil: AUTO"
End If



Debounce Pinc.2 , 0 , Dec_y4_modus                               ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_y4_modus                               ' Impuls von Taster erkennen
                    Goto Weiter8

Dec_y4_modus:
                    If Y4_modus = 0 Then
                    Y4_modus = 2
                    Else
                    Y4_modus = Y4_modus - 1
                    End If
                    Eram_y4_modus = Y4_modus
                    Taster_gedrueckt = 1
                    Goto Weiter8

Inc_y4_modus:
                    If Y4_modus = 2 Then
                    Y4_modus = 0
                    Else
                    Y4_modus = Y4_modus + 1
                    End If
                    Eram_y4_modus = Y4_modus
                    Taster_gedrueckt = 1
                    Goto Weiter8

 Weiter8:




End If
'-------------------------------------------------------------------------------
                 If Anzeigeseite = 11 Then
Locate 4 , 16
Lcd "B"

Locate 1 , 1
Lcd "Einstellmodus"                                              ' Pumpenmodus einstellen


Locate 3 , 1
If Sensortyp = 1 Then
Lcd "PT1000 Sensor "
End If
If Sensortyp = 2 Then
Lcd "1-wire Sensor "
End If




Debounce Pinc.2 , 0 , Dec_sensortyp                              ' Impuls von Taster erkennen
Debounce Pinc.3 , 0 , Inc_sensortyp                              ' Impuls von Taster erkennen
                    Goto Weiter9

Dec_sensortyp:
                    If Sensortyp = 2 Then
                    Sensortyp = 1
                    Else
                    Sensortyp = 2
                    End If
                    Eram_sensortyp = Sensortyp
                    Taster_gedrueckt = 1
                    Goto Weiter9

Inc_sensortyp:
                    If Sensortyp = 1 Then
                    Sensortyp = 2
                    Else
                    Sensortyp = 1
                    End If
                    Eram_sensortyp = Sensortyp
                    Taster_gedrueckt = 1
                    Goto Weiter9

 Weiter9:




End If
'-------------------------------------------------------------------------------


Reset Watchdog                                                   ' Zurücksetzen des Wachtdog Zählers; (Nach Ablau des Zählers wird reset ausgelöst)


Loop
End