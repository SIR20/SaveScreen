{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}

{$title SaveScreen}

{$apptype windows}
uses System.IO, System.Windows.Forms, System.Drawing, System.Drawing.Imaging, System.Threading, System.Windows.Input;

const
  Ctrl = 17;
  PrtScreen = 44;
  Escape = 27;
  Alt = 262144;
  Shift = 16;
  Key_S = 83;
  Key_A = 65;
  Key_Q = 81;
  Key_E = 69;

type
  ScreenEditor = class
    private Screens := new List<Image>;
    
    public procedure ScreenSave(im_path: string; im: Image);
    begin
      case Path.GetExtension(im_path).ToLower of
        '.png': Im.Save(im_path, ImageFormat.Png);
        '.jpg': Im.Save(im_path, ImageFormat.Jpeg);
        '.bmp': Im.Save(im_path, ImageFormat.Bmp);
      end;
      im.Dispose;
    end;
  
  public
    
    public procedure ScreensSave(path: string);
    begin
      Screens.ForEach((i, j) -> ScreenSave($'{path}\image{j}.jpg', i));
      Screens.ForEach(i -> begin i.Dispose end);
    end;
    
    public procedure ScreenSaveToMemory(im: Image) := Clipboard.SetImage(im);
    public procedure ScreenAdd(im: Image) := Screens.Add(im);
    public procedure ScreensClear := Screens.Clear;
    
    public auto property MultyScreen: boolean;
    public property ScreensCount: integer read Screens.Count;
  end;

function GetKeyState(key: integer): integer;
  external 'User32.dll' name 'GetAsyncKeyState';

function FileSaveDialog: string;
begin
  var save_dialog := new SaveFileDialog;
  save_dialog.FileName := 'image.jpg';
  save_dialog.Filter := 'JPG File(*.jpg)|*.jpg|PNG File(*.png)|*.png|Bitmap File(*.bmp)|*.bmp';
  case save_dialog.ShowDialog of
    DialogResult.OK: result := save_dialog.FileName
  end;
end;

function FolderOpenDialog: string;
begin
  var FolderOpen := new FolderBrowserDialog;
  case FolderOpen.ShowDialog of
    DialogResult.OK: result := FolderOpen.SelectedPath;
  end;
end;

function MakeScreenShot: Bitmap;
begin
  var sz := Screen.PrimaryScreen.Bounds.Size;
  Result := new Bitmap(sz.Width, sz.Height);
  Graphics.FromImage(Result).CopyFromScreen(0, 0, 0, 0, sz);
end;

begin
  var th: Thread;
  th := new Thread(()->begin
    var screen_down := false;
    var Screen := new ScreenEditor;
    
    while true do
    begin
      if (GetKeyState(Ctrl) <> 0) and (GetKeyState(Shift) <> 0) and (GetKeyState(Key_S) <> 0) then //Прямое сохранение файла
      begin
        var img := Clipboard.GetImage;
        if img <> nil then
        begin
          var path := FileSaveDialog;
          if path.Length > 0 then
            Screen.ScreenSave(path, img);
        end;
      end;
      
      if (GetKeyState(Ctrl) <> 0) and (GetKeyState(PrtScreen) <> 0) then //Изменение Скриншота
      begin
        var screenshot := MakeScreenShot;
        {$region GitHub:Sun Serega}
        var MainForm := new Form;
        MainForm.FormBorderStyle := FormBorderStyle.None;
        MainForm.WindowState := FormWindowState.Minimized;
        MainForm.BackColor := Color.FromArgb(128, 128, 128);
        MainForm.Opacity := 1 / 255;
        MainForm.ShowInTaskbar := false;
        
        var SelectRectForm := new Form;
        SelectRectForm.AddOwnedForm(MainForm);
        SelectRectForm.AllowTransparency := true;
        SelectRectForm.TransparencyKey := Color.Black;
        SelectRectForm.BackColor := Color.Black;
        SelectRectForm.FormBorderStyle := FormBorderStyle.None;
        SelectRectForm.WindowState := FormWindowState.Minimized;
        SelectRectForm.ShowInTaskbar := false;;
        SelectRectForm.Shown += (o, e)->
        begin
          MainForm.WindowState := FormWindowState.Maximized;
          SelectRectForm.WindowState := FormWindowState.Maximized;
        end;
        
        var SelectRect := new PictureBox;
        SelectRectForm.Controls.Add(SelectRect);
        SelectRect.Dock := DockStyle.Fill;
        
        var p1: Point?;
        var p2: Point?;
        
        MainForm.MouseDown += (o, e)->
        begin
          if e.Button = MouseButtons.Left then
          begin
            p1 := e.Location;
            p2 := e.Location;
          end else
            p1 := nil;
          SelectRect.Invalidate;
        end;
        
        MainForm.MouseMove += (o, e)->
        begin
          if p1 = nil then exit;
          p2 := e.Location;
          SelectRect.Invalidate;
        end;
        
        MainForm.MouseUp += (o, e)->
        begin
          if p1 = nil then exit;
          p2 := e.Location;
          
          if e.Button = MouseButtons.Left then
          begin
            var x1 := p1.Value.X;
            var y1 := p1.Value.Y;
            var x2 := p2.Value.X;
            var y2 := p2.Value.Y;
            
            if (Abs(x1 - x2) > 5) and (Abs(y1 - y2) > 5) then
            begin
              if x1 > x2 then Swap(x1, x2);
              if y1 > y2 then Swap(y1, y2);
              
              var res := new Bitmap(x2 - x1, y2 - y1);
              Graphics.FromImage(res).DrawImageUnscaledAndClipped(screenshot, new Rectangle(-x1, -y1, screenshot.Width, screenshot.Height));
              Clipboard.SetImage(res);
              MainForm.Close;
              SelectRectForm.Close;
            end;
          end;
          
          p1 := nil;
          SelectRect.Invalidate;
        end;
        
        SelectRect.Paint += (o, e)->
        begin
          var gr := e.Graphics;
          
          var lp1 := p1;
          var lp2 := p2;
          
          if (lp1 <> nil) and (lp2 <> nil) then
          begin
            var x1 := lp1.Value.X;
            var y1 := lp1.Value.Y;
            var x2 := lp2.Value.X;
            var y2 := lp2.Value.Y;
            
            if (Abs(x1 - x2) > 5) and (Abs(y1 - y2) > 5) then
            begin
              if x1 > x2 then Swap(x1, x2);
              if y1 > y2 then Swap(y1, y2);
              gr.DrawRectangle(new Pen(Color.Red, 3), x1, y1, x2 - x1, y2 - y1);
            end;
            
          end;
          
        end;
        
        SelectRectForm.Shown += (o, e)->
        begin
          var thr := new Thread(()->Application.Run(MainForm));
          thr.ApartmentState := ApartmentState.STA;
          thr.Start;
        end;
        Application.Run(SelectRectForm);
        {$endregion GitHub:Sun Serega}
      end;
      
      if(GetKeyState(Ctrl) <> 0) and (GetKeyState(Key_Q) <> 0) then //Включение/Выключение мультискриншотного режима
      begin
        Screen.MultyScreen := not Screen.MultyScreen;
        
        var notif := new NotifyIcon;
        notif.Icon := SystemIcons.Information;
        notif.Visible := true;
        
        notif.BalloonTipClosed += (o, e)->
        begin
          notif.Visible := false;
          notif.Dispose;
        end;
        
        if Screen.MultyScreen then  notif.BalloonTipText := 'Включен режим мультискриншотов'
        else begin
          notif.BalloonTipText := 'Режим мультискриншотов выключен';
          if Screen.ScreensCount > 0 then
          begin
            var path := FolderOpenDialog;
            if path.Length > 0 then
              Screen.ScreensSave(path);
            Screen.ScreensClear;
          end;
        end;
        notif.ShowBalloonTip(3);
        sleep(3000);
        notif.Visible := false;
      end;
      
      if(GetKeyState(PrtScreen) <> 0) then screen_down := true;
      
      if(GetKeyState(PrtScreen) = 0) then 
      begin
        if Screen.MultyScreen then
        begin
          var buff_image := Clipboard.GetImage;
          if buff_image <> nil then Screen.ScreenAdd(buff_image);
        end;
      end;
      
      if (GetKeyState(Ctrl) <> 0) and (GetKeyState(Shift) <> 0) and (GetKeyState(Key_E) <> 0) then Halt(0);//Завершение программы
    end;
    sleep(50);
  end);
  th.ApartmentState := ApartmentState.STA;
  th.Start;
end.