{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}

{$title SaveScreen}

{$apptype windows}
uses System.IO, System.Windows.Forms, System.Drawing, System.Drawing.Imaging, System.Threading, System.Windows.Input, Microsoft.Win32, System.Timers, System.Diagnostics;
uses System.IO.Pipes;
uses System.Text;

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
  Key_D = 68;

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
      Screens.ForEach((i, j) -> ScreenSave(GetSuitableFilePath(path, j), i));
      Screens.ForEach(i -> begin i.Dispose end);
    end;
    
    private function GetSuitableFilePath(path: string; j: integer): string;
    begin
      var i := j;
      var screenPath := $'{path}\images{j}.jpg';
      while &File.Exists(screenPath) do
      begin
        screenPath := $'{path}\images{j}.jpg';
        j += 1;
      end;
      result := screenPath;
    end;
    
    public procedure ScreenSaveToMemory(im: Image) := Clipboard.SetImage(im);
    public procedure ScreenAdd(im: Image) := Screens.Add(im);
    public procedure ScreensClear := Screens.Clear;
    
    public auto property MultyScreen: boolean;
    public property ScreensCount: integer read Screens.Count;
  end;

function GetKeyState(key: integer): integer;
  external 'User32.dll' name 'GetAsyncKeyState';

///Выбор файла для сохранения скриншота
function FileSaveDialog: string;//Выбор файла для сохранения скриншота
begin
  var save_dialog := new SaveFileDialog;
  save_dialog.FileName := 'image.jpg';
  save_dialog.Filter := 'JPG File(*.jpg)|*.jpg|PNG File(*.png)|*.png|Bitmap File(*.bmp)|*.bmp';
  case save_dialog.ShowDialog of
    DialogResult.OK: result := save_dialog.FileName
  end;
end;

///Выбор папки для сохранения скриншотов
function FolderOpenDialog: string;//Выбор папки для сохранения скриншотов
begin
  var FolderOpen := new FolderBrowserDialog;
  case FolderOpen.ShowDialog of
    DialogResult.OK: result := FolderOpen.SelectedPath;
  end;
end;

///Создание скриншота
function MakeScreenShot: Bitmap;//Создание скриншота
begin
  var sz := Screen.PrimaryScreen.Bounds.Size;
  Result := new Bitmap(sz.Width, sz.Height);
  Graphics.FromImage(Result).CopyFromScreen(0, 0, 0, 0, sz);
end;

///Форма - справочник
procedure ShowHelper;//Форма - справочник
begin
  var f := new Form;
  f.Width := 500;
  f.Height := 300;
  f.Text := 'Справка';
  f.StartPosition := FormStartPosition.CenterScreen;
  f.TopMost := true;
  f.KeyPreview:=false;
  
  var label_4 := new TextBox;
  label_4.Left := 10;
  label_4.Top := 10;
  label_4.Width := f.Width;
  label_4.BorderStyle := BorderStyle.None;
  label_4.Enabled := false;
  label_4.Text := 'Ctrl + Shift + E - Заершает работу программы.';
  
  var label_1 := new TextBox;
  label_1.Left := 10;
  label_1.Top := 40;
  label_1.Width := f.Width;
  label_1.BorderStyle := BorderStyle.None;
  label_1.Enabled := false;
  label_1.Text := 'Ctrl + Shift + S - Сохраняет скриншот по выбранному пути.';
  
  var label_2 := new TextBox;
  label_2.Left := 10;
  label_2.Top := 70;
  label_2.Width := f.Width;
  label_2.BorderStyle := BorderStyle.None;
  label_2.Enabled := false;
  label_2.Text := 'Ctrl + PrtScreen - Делает скриншот и позволяет обрезать скриншот,и сохраняет в буфер.';
  
  var label_3 := new TextBox;
  label_3.Left := 10;
  label_3.Top := 100;
  label_3.Width := f.Width;
  label_3.Height := 55;
  label_3.BorderStyle := BorderStyle.None;
  label_3.Enabled := false;
  label_3.Text := $'Ctrl + Q - Включает/Выключает режим мультискриншотов{NewLine}(Возможность сделать несколько скриншотов подряд.После выключения этого режима выбираете куда сохранить).';
  label_3.Multiline := true;
  
  f.Controls.Add(label_1);
  f.Controls.Add(label_2);
  f.Controls.Add(label_3);
  f.Controls.Add(label_4);
  Application.Run(f);
end;

///Открывает форму для обрезки скришота
procedure CutScreen(scr: Image; s: ScreenEditor; to_memory: boolean := true);//Открывает форму для обрезки скришота
begin
  var screenshot := scr;
  
  {$region GitHub:SunSerega}
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
  SelectRectForm.ShowInTaskbar := false;
  MainForm.Cursor := Cursors.Cross;
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
        if to_memory then
          Clipboard.SetImage(res)
        else
          s.ScreenAdd(res);
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
    var thr := new Thread(() -> Application.Run(MainForm));
    thr.ApartmentState := ApartmentState.STA;
    thr.Start;
  end;
  Application.Run(SelectRectForm);
  {$endregion GitHub:SunSerega}
end;

///Сохраняет скришот
procedure SaveImage(scr: ScreenEditor);//Сохраняет скришот
begin
  var img := Clipboard.GetImage;
  if img <> nil then
  begin
    var path := FileSaveDialog;
    if path.Length > 0 then
      scr.ScreenSave(path, img);
  end;
end;

///Включает/Выключает режим мультискриншотов
procedure MultyScreen(Screen_s: ScreenEditor; time: integer);//Включает/Выключает режим мультискриншотов
begin
  Screen_s.MultyScreen := not Screen_s.MultyScreen;
  
  var multy_notif := new NotifyIcon;
  multy_notif.Icon := SystemIcons.Information;
  multy_notif.Visible := true;
  
  multy_notif.BalloonTipClosed += (o, e)->
  begin
    multy_notif.Visible := false;
    multy_notif.Dispose;
  end;
  
  if Screen_s.MultyScreen then 
    multy_notif.BalloonTipText := 'Включен режим мультискриншотов'
  else begin
    multy_notif.BalloonTipText := 'Режим мультискриншотов выключен';
    if Screen_s.ScreensCount > 0 then
    begin
      var path := FolderOpenDialog;
      if path.Length > 0 then
        Screen_s.ScreensSave(path);
      Screen_s.ScreensClear;
    end;
  end;
  multy_notif.ShowBalloonTip(Round(time / 1000));
  var t := new System.Timers.Timer(time);
  t.AutoReset := false;
  t.Elapsed += (o, e)-> begin
    multy_notif.Visible := false;
    t.Stop;
    t.Close;
    t.Dispose;
  end;
  t.Start;
end;

///Закрывает программу
procedure CloseSaveScreen(time: integer);//Закрывает программу
begin
  var end_notif := new NotifyIcon;
  end_notif.Icon := SystemIcons.Information;
  end_notif.Visible := true;
  
  end_notif.BalloonTipClosed += (o, e)->
  begin
    end_notif.Visible := false;
    end_notif.Dispose;
  end;
  
  end_notif.BalloonTipText := 'Закрытие SaveScreen';
  end_notif.ShowBalloonTip(Round(time / 1000));
  var t := new System.Timers.Timer(time);
  t.AutoReset := false;
  t.Elapsed += (o, e)-> begin
    end_notif.Visible := false;
    t.Stop;
    t.Close;
    t.Dispose;
  end;
  t.Start;
  System.Diagnostics.Process.GetCurrentProcess().Kill();
end;

const
  time = 3000;
  mutex_name = 'ID=1.SaveScreen.exe';
  pipe_name = 'SIR\SaveScreen\ID=1';

begin
  var open_flag := false;
  var mute_x := new Mutex(true, mutex_name, open_flag);
  if not open_flag then //Если программа уже запущена
  begin
    if ParamCount = 0
      then System.Diagnostics.Process.GetCurrentProcess().Kill();
    
    var arg := ParamStr(1);
    
    var PipeClient := new NamedPipeClientStream(pipe_name);
    PipeClient.Connect;
    var msg := Encoding.UTF8.GetBytes(arg + '&');
    PipeClient.Write(msg, 0, msg.Length);
    System.Diagnostics.Process.GetCurrentProcess().Kill();
  end;
  
  var th: Thread;
  th := new Thread(() -> begin
    var Screen_s := new ScreenEditor;
    
    var listen_thread: Thread;
    listen_thread := new Thread(() -> begin
      var PipeServer := new NamedPipeServerStream(pipe_name);
      var data: array of char;
      var sr: StreamReader;
      var msg: string;
      while true do
      begin
        PipeServer.WaitForConnection;
        data := new char[20];
        sr := new StreamReader(PipeServer);
        while true do 
        begin
          sr.ReadBlock(data, 0, data.Length);
          msg += data.JoinToString;
          if data.LastIndexOf('&') > 0 then
            break;
        end;
        PipeServer.Disconnect;
        
        msg := msg.Remove(msg.IndexOf('&'));
        case msg of
          'CreateCutScreen': CutScreen(MakeScreenShot, Screen_s, not Screen_s.MultyScreen);
          'SaveScreen': SaveImage(Screen_s);
          'MultyScreen': MultyScreen(Screen_s, time);
          'CloseApp': CloseSaveScreen(time);
        end;
        msg := '';
      end;
    end);
    listen_thread.ApartmentState := ApartmentState.STA;
    listen_thread.Start;
    
    var screen_down := false;
    var multy_down := false;
    var editor_down := false;
    var save_down := false;
    
    try
      var sft := Registry.CurrentUser.OpenSubKey('SOFTWARE', true);
      var reg_save := sft.CreateSubKey('SaveScreen');
      var res := reg_save.GetValue('Open');
      if res = nil then
      begin
        var helper_thread:= new Thread(ShowHelper);
        helper_thread.Start;
        reg_save.SetValue('Open', true)
      end;
    except
    end;
    
    var start_notif := new NotifyIcon;
    start_notif.Icon := SystemIcons.Information;
    start_notif.Visible := true;
    start_notif.BalloonTipText := 'SaveScreen готов к работе';
    
    start_notif.BalloonTipClosed += (o, e)->
    begin
      start_notif.Visible := false;
      start_notif.Dispose;
    end;   
    
    start_notif.ShowBalloonTip(Round(time / 1000));
    var t := new System.Timers.Timer(time);
    t.AutoReset := false;
    t.Elapsed += (o, e)-> begin
      start_notif.Visible := false;
      t.Stop;
      t.Close;
      t.Dispose;
    end;
    t.Start;
    
    while true do
    begin
      
      if(GetKeyState(Ctrl) <> 0) and (GetKeyState(Shift) <> 0) and (GetKeyState(Key_S) <> 0) then save_down := true;//0
      if(GetKeyState(Ctrl) = 0) and (GetKeyState(Shift) = 0) and (GetKeyState(Key_S) = 0) and save_down then//0:Прямое сохранение файла
      begin
        SaveImage(Screen_s);
        save_down := false;
      end;
      
      if(GetKeyState(Ctrl) <> 0) and (GetKeyState(PrtScreen) <> 0) then editor_down := true;//1
      if(GetKeyState(Ctrl) = 0) and (GetKeyState(PrtScreen) = 0) and editor_down then//1:Изменение Скриншота
      begin
        if Screen_s.MultyScreen then
          CutScreen(MakeScreenShot, Screen_s, false)
        else
          CutScreen(MakeScreenShot, Screen_s);
        editor_down := false
      end;
      
      if(GetKeyState(Ctrl) <> 0) and (GetKeyState(Key_Q) <> 0) then multy_down := true;//2
      if(GetKeyState(Ctrl) = 0) and (GetKeyState(Key_Q) = 0) and multy_down then//2:Включение/Выключение мультискриншотного режима
      begin
        MultyScreen(Screen_s, time);
        multy_down := false;
      end;
      
      if(GetKeyState(PrtScreen) <> 0) and (GetKeyState(Ctrl) = 0) then screen_down := true;//1
      if((GetKeyState(PrtScreen) = 0) and screen_down) then //1:Скриншот
      begin
        if Screen_s.MultyScreen then
        begin
          var buff_image := Clipboard.GetImage;
          if buff_image <> nil then Screen_s.ScreenAdd(buff_image);
        end;
        screen_down := false;
      end;
      
      if (GetKeyState(Ctrl) <> 0) and (GetKeyState(Shift) <> 0) and (GetKeyState(Key_D) <> 0) then ShowHelper;//Справочник
      
      if (GetKeyState(Ctrl) <> 0) and (GetKeyState(Shift) <> 0) and (GetKeyState(Key_E) <> 0) then CloseSaveScreen(time);
      
      sleep(50);
    end;
  end);
  th.ApartmentState := ApartmentState.STA;
  th.Start;
end.