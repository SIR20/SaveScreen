﻿{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}

{$title SaveScreen}

{$apptype windows}
uses System.Windows.Forms, System.Drawing, System.Threading, System.Windows.Input;

function GetKeyState(key: integer): integer;
  external 'User32.dll' name 'GetAsyncKeyState';

const
  Ctrl = 17;
  PrtScreen = 44;
  Escape = 27;
  Alt = 262144;
  Shift = 16;
  Key_S = 83;
  Key_A = 65;
  Key_Q = 81;

//!!!!!!!!!!!!!!!!!!!!!!!!!Сделать справку при первом запуске
//!!!!!!!!!!!!!!!!!!!!!!!!!Через реестры

begin
  var th_main: Thread;
  th_main := new Thread(() -> begin
    while true do 
    begin
      var flag := false;
      var option := -1;
      var multy_screen := false;
      var Images := new List<Image>;
      while not flag do
      begin
        
        if (GetKeyState(Ctrl) <> 0) and (GetKeyState(Shift) <> 0) and (GetKeyState(Key_S) <> 0) then //Прямое сохранение файла
        begin
          flag := true;
          option := 0;
        end;
        
        if (GetKeyState(Ctrl) <> 0) and (GetKeyState(Shift) <> 0) and (GetKeyState(Key_A) <> 0) then //Изменение файла
        begin
          flag := true;
          option := 1;
        end;
        
        if(GetKeyState(Ctrl) <> 0) and (GetKeyState(Key_Q) <> 0) then //Включение/Выключение мультискриншотного режима
        begin
          multy_screen := not multy_screen;
          
          var notif := new NotifyIcon;
          notif.Icon := SystemIcons.Information;
          notif.Visible := true;
          
          notif.BalloonTipClosed += (o, e)->
          begin
            notif.Visible := false;
            notif.Dispose;
          end;
          
          if multy_screen then  notif.BalloonTipText := 'Включен режим мультискриншотов'
          else begin
            notif.BalloonTipText := 'Режим мультискриншотов выключен';
            option := 2;
            flag := true;
          end;
          notif.ShowBalloonTip(3);
          sleep(3000);
          notif.Visible := false;
        end;
        
        if(GetKeyState(PrtScreen) <> 0) then
        begin
          if multy_screen then
          begin
            var buff_image := Clipboard.GetImage;
            if buff_image <> nil then Images.Add(buff_image);
          end;
        end;
        
        if(GetKeyState(Ctrl) <> 0) and (GetKeyState(Shift) <> 0) and (GetKeyState(Escape) <> 0) then Thread.CurrentThread.Abort; //Завершение программы
        sleep(500);
      end;
      
      var imagesv := Clipboard.GetImage;
      if imagesv <> nil then
      begin
        var f := new Form;
        f.StartPosition := FormStartPosition.CenterScreen;
        f.TopMost := true;
        case option of
          0:
            begin
              var save_dialog := new SaveFileDialog;
              save_dialog.FileName := 'image.jpg';
              save_dialog.Filter := 'JPG File(*.jpg)|*.jpg|PNG File(*.png)|*.png|Bitmap File(*.bmp)|*.bmp';
              case save_dialog.ShowDialog(f) of
                DialogResult.OK: imagesv.Save(save_dialog.FileName);
              end;
            end;
          1:
            begin
              var redimage := new Bitmap(imagesv, imagesv.Width, imagesv.Height);
              var cimage: Bitmap;
              var w := System.Windows.Forms.Screen.PrimaryScreen.Bounds.Size.Width;
              var h := System.Windows.Forms.Screen.PrimaryScreen.Bounds.Size.Height;
              var p := new PictureBox;
              f.StartPosition := FormStartPosition.CenterScreen;
              f.WindowState := FormWindowState.Maximized;
              f.Width := imagesv.Width;
              f.Height := imagesv.Height;
              f.KeyPreview := true;
              f.Load += (o, e)-> begin
                f.TopMost := false;
              end;
              
              f.KeyDown += (o, e)-> begin
                if (e.Control) and (e.KeyCode = Keys.S) then
                begin
                  if cimage = nil then
                    cimage := imagesv as Bitmap;
                  var save_dialog := new SaveFileDialog;
                  save_dialog.FileName := 'image.jpg';
                  save_dialog.Filter := 'JPG File(*.jpg)|*.jpg|PNG File(*.png)|*.png|Bitmap File(*.bmp)|*.bmp';
                  case save_dialog.ShowDialog(f) of
                    DialogResult.OK: cimage.Save(save_dialog.FileName);
                  end;
                end;
                
                if (e.Control) and (e.KeyCode = Keys.P) then
                  Clipboard.SetImage(cimage);
                
                if (e.Control) and (e.KeyCode = Keys.Z) then
                begin
                  redimage := new Bitmap(imagesv, imagesv.Width, imagesv.Height);
                  p.Image := redimage;
                  cimage := redimage;
                end;
              end;
              
              var sx, sy, ex, ey: integer;
              
              p := new PictureBox;
              p.SizeMode := PictureBoxSizeMode.AutoSize;
              p.Image := redimage;
              p.MouseDown += (o, e)-> begin
                if e.Button = MouseButtons.Left then
                begin
                  sx := e.X;
                  sy := e.Y;
                end;
              end;
              
              p.MouseUp += (o, e)-> begin
                if e.Button = MouseButtons.Left then
                begin
                  ex := e.X;
                  ey := e.Y;
                end;
              end;
              
              p.MouseClick += (o, e)-> begin
                if e.Button = MouseButtons.Right then
                begin
                  if (sx <> ex) or (sy <> ey) then
                  begin
                    try
                      var pimage := p.Image as Bitmap;
                      cimage := pimage.Clone(new Rectangle(sx, sy, ex - sx, ey - sy), pimage.PixelFormat);
                      p.Image := cimage;
                    except
                    end;
                  end;
                end;
              end;
              f.Controls.Add(p);
              
              var pan := new Panel;
              pan.Controls.Add(p);
              pan.Width := w;
              pan.Height := h - 100;
              pan.AutoScroll := true;
              f.Controls.Add(pan);
              
              Application.Run(f);
            end;
          2:
            begin
              if Images.Count > 0 then 
              begin
                var FolderOpen := new FolderBrowserDialog;
                case FolderOpen.ShowDialog of
                  DialogResult.OK:
                    begin
                      var path := FolderOpen.SelectedPath;
                      for var i := 0 to Images.Count - 1 do
                      begin
                        var image := Images[i];
                        image.Save($'{path}\image{i}s.png');
                      end;
                    end;
                end;
              end;
              Images.Clear;
            end;
        end;
      end;
    end;
  end);
  th_main.ApartmentState := ApartmentState.STA;
  th_main.Start;
end.