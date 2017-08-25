namespace DigitalCrossoverDemo
{
    partial class Form1
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            this.label2 = new System.Windows.Forms.Label();
            this.label3 = new System.Windows.Forms.Label();
            this.txtLowerFreq = new System.Windows.Forms.TextBox();
            this.txtUpperFreq = new System.Windows.Forms.TextBox();
            this.btnPlay = new System.Windows.Forms.Button();
            this.btnStop = new System.Windows.Forms.Button();
            this.lblFileName = new System.Windows.Forms.Label();
            this.btnOpenFile = new System.Windows.Forms.Button();
            this.label1 = new System.Windows.Forms.Label();
            this.label4 = new System.Windows.Forms.Label();
            this.txtLowerTrans = new System.Windows.Forms.TextBox();
            this.txtUpperTrans = new System.Windows.Forms.TextBox();
            this.tmrUpdateViz = new System.Windows.Forms.Timer(this.components);
            this.picWaveLeftWoofer = new System.Windows.Forms.PictureBox();
            this.label5 = new System.Windows.Forms.Label();
            this.rdoPlayWoofer = new System.Windows.Forms.RadioButton();
            this.rdoPlayMidrange = new System.Windows.Forms.RadioButton();
            this.rdoPlayTweeter = new System.Windows.Forms.RadioButton();
            this.label6 = new System.Windows.Forms.Label();
            this.label7 = new System.Windows.Forms.Label();
            this.label8 = new System.Windows.Forms.Label();
            this.label9 = new System.Windows.Forms.Label();
            this.label10 = new System.Windows.Forms.Label();
            this.label11 = new System.Windows.Forms.Label();
            this.picWaveRightWoofer = new System.Windows.Forms.PictureBox();
            this.picWaveLeftMidrange = new System.Windows.Forms.PictureBox();
            this.picWaveRightMidrange = new System.Windows.Forms.PictureBox();
            this.picWaveLeftTweeter = new System.Windows.Forms.PictureBox();
            this.picWaveRightTweeter = new System.Windows.Forms.PictureBox();
            this.picFreqLeftWoofer = new System.Windows.Forms.PictureBox();
            this.picFreqRightWoofer = new System.Windows.Forms.PictureBox();
            this.picFreqLeftMidrange = new System.Windows.Forms.PictureBox();
            this.picFreqRightMidrange = new System.Windows.Forms.PictureBox();
            this.picFreqLeftTweeter = new System.Windows.Forms.PictureBox();
            this.picFreqRightTweeter = new System.Windows.Forms.PictureBox();
            this.chkDrawFFTs = new System.Windows.Forms.CheckBox();
            this.chkDrawWaves = new System.Windows.Forms.CheckBox();
            this.lblResult = new System.Windows.Forms.Label();
            this.button2 = new System.Windows.Forms.Button();
            this.tbarFilePosition = new System.Windows.Forms.TrackBar();
            this.tbarVolume = new System.Windows.Forms.TrackBar();
            this.button1 = new System.Windows.Forms.Button();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveLeftWoofer)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveRightWoofer)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveLeftMidrange)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveRightMidrange)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveLeftTweeter)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveRightTweeter)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqLeftWoofer)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqRightWoofer)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqLeftMidrange)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqRightMidrange)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqLeftTweeter)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqRightTweeter)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.tbarFilePosition)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.tbarVolume)).BeginInit();
            this.SuspendLayout();
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(737, 9);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(92, 13);
            this.label2.TabIndex = 2;
            this.label2.Text = "Lower Frequency:";
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(847, 9);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(92, 13);
            this.label3.TabIndex = 3;
            this.label3.Text = "Upper Frequency:";
            // 
            // txtLowerFreq
            // 
            this.txtLowerFreq.Location = new System.Drawing.Point(740, 25);
            this.txtLowerFreq.Name = "txtLowerFreq";
            this.txtLowerFreq.Size = new System.Drawing.Size(100, 20);
            this.txtLowerFreq.TabIndex = 0;
            this.txtLowerFreq.Text = "200";
            // 
            // txtUpperFreq
            // 
            this.txtUpperFreq.Location = new System.Drawing.Point(850, 25);
            this.txtUpperFreq.Name = "txtUpperFreq";
            this.txtUpperFreq.Size = new System.Drawing.Size(100, 20);
            this.txtUpperFreq.TabIndex = 1;
            this.txtUpperFreq.Text = "2000";
            // 
            // btnPlay
            // 
            this.btnPlay.Location = new System.Drawing.Point(956, 23);
            this.btnPlay.Name = "btnPlay";
            this.btnPlay.Size = new System.Drawing.Size(75, 23);
            this.btnPlay.TabIndex = 4;
            this.btnPlay.Text = "Play";
            this.btnPlay.UseVisualStyleBackColor = true;
            this.btnPlay.Click += new System.EventHandler(this.btnPlay_Click);
            // 
            // btnStop
            // 
            this.btnStop.Location = new System.Drawing.Point(956, 62);
            this.btnStop.Name = "btnStop";
            this.btnStop.Size = new System.Drawing.Size(75, 23);
            this.btnStop.TabIndex = 5;
            this.btnStop.Text = "Stop";
            this.btnStop.UseVisualStyleBackColor = true;
            this.btnStop.Click += new System.EventHandler(this.btnStop_Click);
            // 
            // lblFileName
            // 
            this.lblFileName.Location = new System.Drawing.Point(85, 9);
            this.lblFileName.Name = "lblFileName";
            this.lblFileName.Size = new System.Drawing.Size(500, 13);
            this.lblFileName.TabIndex = 8;
            // 
            // btnOpenFile
            // 
            this.btnOpenFile.Location = new System.Drawing.Point(8, 4);
            this.btnOpenFile.Name = "btnOpenFile";
            this.btnOpenFile.Size = new System.Drawing.Size(75, 23);
            this.btnOpenFile.TabIndex = 6;
            this.btnOpenFile.Text = "Open...";
            this.btnOpenFile.UseVisualStyleBackColor = true;
            this.btnOpenFile.Click += new System.EventHandler(this.btnOpenFile_Click);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(737, 48);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(88, 13);
            this.label1.TabIndex = 10;
            this.label1.Text = "Lower Transition:";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(847, 48);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(88, 13);
            this.label4.TabIndex = 11;
            this.label4.Text = "Upper Transition:";
            // 
            // txtLowerTrans
            // 
            this.txtLowerTrans.Location = new System.Drawing.Point(740, 64);
            this.txtLowerTrans.Name = "txtLowerTrans";
            this.txtLowerTrans.Size = new System.Drawing.Size(100, 20);
            this.txtLowerTrans.TabIndex = 2;
            this.txtLowerTrans.Text = "50";
            // 
            // txtUpperTrans
            // 
            this.txtUpperTrans.Location = new System.Drawing.Point(850, 64);
            this.txtUpperTrans.Name = "txtUpperTrans";
            this.txtUpperTrans.Size = new System.Drawing.Size(100, 20);
            this.txtUpperTrans.TabIndex = 3;
            this.txtUpperTrans.Text = "50";
            // 
            // tmrUpdateViz
            // 
            this.tmrUpdateViz.Interval = 40;
            this.tmrUpdateViz.Tick += new System.EventHandler(this.tmrUpdateViz_Tick);
            // 
            // picWaveLeftWoofer
            // 
            this.picWaveLeftWoofer.Location = new System.Drawing.Point(104, 101);
            this.picWaveLeftWoofer.Name = "picWaveLeftWoofer";
            this.picWaveLeftWoofer.Size = new System.Drawing.Size(512, 140);
            this.picWaveLeftWoofer.TabIndex = 15;
            this.picWaveLeftWoofer.TabStop = false;
            this.picWaveLeftWoofer.Paint += new System.Windows.Forms.PaintEventHandler(this.picWaveLeftWoofer_Paint);
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(1060, 9);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(67, 13);
            this.label5.TabIndex = 16;
            this.label5.Text = "Play Source:";
            // 
            // rdoPlayWoofer
            // 
            this.rdoPlayWoofer.AutoSize = true;
            this.rdoPlayWoofer.Location = new System.Drawing.Point(1063, 28);
            this.rdoPlayWoofer.Name = "rdoPlayWoofer";
            this.rdoPlayWoofer.Size = new System.Drawing.Size(60, 17);
            this.rdoPlayWoofer.TabIndex = 17;
            this.rdoPlayWoofer.Text = "Woofer";
            this.rdoPlayWoofer.UseVisualStyleBackColor = true;
            this.rdoPlayWoofer.CheckedChanged += new System.EventHandler(this.rdoPlayWoofer_CheckedChanged);
            // 
            // rdoPlayMidrange
            // 
            this.rdoPlayMidrange.AutoSize = true;
            this.rdoPlayMidrange.Checked = true;
            this.rdoPlayMidrange.Location = new System.Drawing.Point(1063, 48);
            this.rdoPlayMidrange.Name = "rdoPlayMidrange";
            this.rdoPlayMidrange.Size = new System.Drawing.Size(69, 17);
            this.rdoPlayMidrange.TabIndex = 18;
            this.rdoPlayMidrange.TabStop = true;
            this.rdoPlayMidrange.Text = "Midrange";
            this.rdoPlayMidrange.UseVisualStyleBackColor = true;
            this.rdoPlayMidrange.CheckedChanged += new System.EventHandler(this.rdoPlayMidrange_CheckedChanged);
            // 
            // rdoPlayTweeter
            // 
            this.rdoPlayTweeter.AutoSize = true;
            this.rdoPlayTweeter.Location = new System.Drawing.Point(1063, 68);
            this.rdoPlayTweeter.Name = "rdoPlayTweeter";
            this.rdoPlayTweeter.Size = new System.Drawing.Size(64, 17);
            this.rdoPlayTweeter.TabIndex = 19;
            this.rdoPlayTweeter.Text = "Tweeter";
            this.rdoPlayTweeter.UseVisualStyleBackColor = true;
            this.rdoPlayTweeter.CheckedChanged += new System.EventHandler(this.rdoPlayTweeter_CheckedChanged);
            // 
            // label6
            // 
            this.label6.AutoSize = true;
            this.label6.Font = new System.Drawing.Font("Microsoft Sans Serif", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label6.Location = new System.Drawing.Point(6, 101);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(79, 16);
            this.label6.TabIndex = 20;
            this.label6.Text = "Left Woofer:";
            // 
            // label7
            // 
            this.label7.AutoSize = true;
            this.label7.Font = new System.Drawing.Font("Microsoft Sans Serif", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label7.Location = new System.Drawing.Point(646, 101);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(89, 16);
            this.label7.TabIndex = 21;
            this.label7.Text = "Right Woofer:";
            // 
            // label8
            // 
            this.label8.AutoSize = true;
            this.label8.Font = new System.Drawing.Font("Microsoft Sans Serif", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label8.Location = new System.Drawing.Point(6, 393);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(92, 16);
            this.label8.TabIndex = 22;
            this.label8.Text = "Left Midrange:";
            // 
            // label9
            // 
            this.label9.AutoSize = true;
            this.label9.Font = new System.Drawing.Font("Microsoft Sans Serif", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label9.Location = new System.Drawing.Point(633, 393);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(102, 16);
            this.label9.TabIndex = 23;
            this.label9.Text = "Right Midrange:";
            // 
            // label10
            // 
            this.label10.AutoSize = true;
            this.label10.Font = new System.Drawing.Font("Microsoft Sans Serif", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label10.Location = new System.Drawing.Point(6, 685);
            this.label10.Name = "label10";
            this.label10.Size = new System.Drawing.Size(84, 16);
            this.label10.TabIndex = 24;
            this.label10.Text = "Left Tweeter:";
            // 
            // label11
            // 
            this.label11.AutoSize = true;
            this.label11.Font = new System.Drawing.Font("Microsoft Sans Serif", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label11.Location = new System.Drawing.Point(641, 685);
            this.label11.Name = "label11";
            this.label11.Size = new System.Drawing.Size(94, 16);
            this.label11.TabIndex = 25;
            this.label11.Text = "Right Tweeter:";
            // 
            // picWaveRightWoofer
            // 
            this.picWaveRightWoofer.Location = new System.Drawing.Point(741, 101);
            this.picWaveRightWoofer.Name = "picWaveRightWoofer";
            this.picWaveRightWoofer.Size = new System.Drawing.Size(512, 140);
            this.picWaveRightWoofer.TabIndex = 26;
            this.picWaveRightWoofer.TabStop = false;
            this.picWaveRightWoofer.Paint += new System.Windows.Forms.PaintEventHandler(this.picWaveRightWoofer_Paint);
            // 
            // picWaveLeftMidrange
            // 
            this.picWaveLeftMidrange.Location = new System.Drawing.Point(104, 393);
            this.picWaveLeftMidrange.Name = "picWaveLeftMidrange";
            this.picWaveLeftMidrange.Size = new System.Drawing.Size(512, 140);
            this.picWaveLeftMidrange.TabIndex = 27;
            this.picWaveLeftMidrange.TabStop = false;
            this.picWaveLeftMidrange.Paint += new System.Windows.Forms.PaintEventHandler(this.picWaveLeftMidrange_Paint);
            // 
            // picWaveRightMidrange
            // 
            this.picWaveRightMidrange.Location = new System.Drawing.Point(740, 393);
            this.picWaveRightMidrange.Name = "picWaveRightMidrange";
            this.picWaveRightMidrange.Size = new System.Drawing.Size(512, 140);
            this.picWaveRightMidrange.TabIndex = 28;
            this.picWaveRightMidrange.TabStop = false;
            this.picWaveRightMidrange.Paint += new System.Windows.Forms.PaintEventHandler(this.picWaveRightMidrange_Paint);
            // 
            // picWaveLeftTweeter
            // 
            this.picWaveLeftTweeter.Location = new System.Drawing.Point(104, 685);
            this.picWaveLeftTweeter.Name = "picWaveLeftTweeter";
            this.picWaveLeftTweeter.Size = new System.Drawing.Size(512, 140);
            this.picWaveLeftTweeter.TabIndex = 29;
            this.picWaveLeftTweeter.TabStop = false;
            this.picWaveLeftTweeter.Paint += new System.Windows.Forms.PaintEventHandler(this.picWaveLeftTweeter_Paint);
            // 
            // picWaveRightTweeter
            // 
            this.picWaveRightTweeter.Location = new System.Drawing.Point(740, 685);
            this.picWaveRightTweeter.Name = "picWaveRightTweeter";
            this.picWaveRightTweeter.Size = new System.Drawing.Size(512, 140);
            this.picWaveRightTweeter.TabIndex = 30;
            this.picWaveRightTweeter.TabStop = false;
            this.picWaveRightTweeter.Paint += new System.Windows.Forms.PaintEventHandler(this.picWaveRightTweeter_Paint);
            // 
            // picFreqLeftWoofer
            // 
            this.picFreqLeftWoofer.Location = new System.Drawing.Point(104, 247);
            this.picFreqLeftWoofer.Name = "picFreqLeftWoofer";
            this.picFreqLeftWoofer.Size = new System.Drawing.Size(512, 140);
            this.picFreqLeftWoofer.TabIndex = 31;
            this.picFreqLeftWoofer.TabStop = false;
            this.picFreqLeftWoofer.Paint += new System.Windows.Forms.PaintEventHandler(this.picFreqLeftWoofer_Paint);
            // 
            // picFreqRightWoofer
            // 
            this.picFreqRightWoofer.Location = new System.Drawing.Point(741, 247);
            this.picFreqRightWoofer.Name = "picFreqRightWoofer";
            this.picFreqRightWoofer.Size = new System.Drawing.Size(512, 140);
            this.picFreqRightWoofer.TabIndex = 32;
            this.picFreqRightWoofer.TabStop = false;
            this.picFreqRightWoofer.Paint += new System.Windows.Forms.PaintEventHandler(this.picFreqRightWoofer_Paint);
            // 
            // picFreqLeftMidrange
            // 
            this.picFreqLeftMidrange.Location = new System.Drawing.Point(104, 539);
            this.picFreqLeftMidrange.Name = "picFreqLeftMidrange";
            this.picFreqLeftMidrange.Size = new System.Drawing.Size(512, 140);
            this.picFreqLeftMidrange.TabIndex = 33;
            this.picFreqLeftMidrange.TabStop = false;
            this.picFreqLeftMidrange.Paint += new System.Windows.Forms.PaintEventHandler(this.picFreqLeftMidrange_Paint);
            // 
            // picFreqRightMidrange
            // 
            this.picFreqRightMidrange.Location = new System.Drawing.Point(740, 539);
            this.picFreqRightMidrange.Name = "picFreqRightMidrange";
            this.picFreqRightMidrange.Size = new System.Drawing.Size(512, 140);
            this.picFreqRightMidrange.TabIndex = 34;
            this.picFreqRightMidrange.TabStop = false;
            this.picFreqRightMidrange.Paint += new System.Windows.Forms.PaintEventHandler(this.picFreqRightMidrange_Paint);
            // 
            // picFreqLeftTweeter
            // 
            this.picFreqLeftTweeter.Location = new System.Drawing.Point(104, 831);
            this.picFreqLeftTweeter.Name = "picFreqLeftTweeter";
            this.picFreqLeftTweeter.Size = new System.Drawing.Size(512, 140);
            this.picFreqLeftTweeter.TabIndex = 35;
            this.picFreqLeftTweeter.TabStop = false;
            this.picFreqLeftTweeter.Paint += new System.Windows.Forms.PaintEventHandler(this.picFreqLeftTweeter_Paint);
            // 
            // picFreqRightTweeter
            // 
            this.picFreqRightTweeter.Location = new System.Drawing.Point(740, 831);
            this.picFreqRightTweeter.Name = "picFreqRightTweeter";
            this.picFreqRightTweeter.Size = new System.Drawing.Size(512, 140);
            this.picFreqRightTweeter.TabIndex = 36;
            this.picFreqRightTweeter.TabStop = false;
            this.picFreqRightTweeter.Paint += new System.Windows.Forms.PaintEventHandler(this.picFreqRightTweeter_Paint);
            // 
            // chkDrawFFTs
            // 
            this.chkDrawFFTs.AutoSize = true;
            this.chkDrawFFTs.Location = new System.Drawing.Point(1154, 27);
            this.chkDrawFFTs.Name = "chkDrawFFTs";
            this.chkDrawFFTs.Size = new System.Drawing.Size(78, 17);
            this.chkDrawFFTs.TabIndex = 37;
            this.chkDrawFFTs.Text = "Draw FFTs";
            this.chkDrawFFTs.UseVisualStyleBackColor = true;
            // 
            // chkDrawWaves
            // 
            this.chkDrawWaves.AutoSize = true;
            this.chkDrawWaves.Checked = true;
            this.chkDrawWaves.CheckState = System.Windows.Forms.CheckState.Checked;
            this.chkDrawWaves.Location = new System.Drawing.Point(1154, 48);
            this.chkDrawWaves.Name = "chkDrawWaves";
            this.chkDrawWaves.Size = new System.Drawing.Size(88, 17);
            this.chkDrawWaves.TabIndex = 38;
            this.chkDrawWaves.Text = "Draw Waves";
            this.chkDrawWaves.UseVisualStyleBackColor = true;
            // 
            // lblResult
            // 
            this.lblResult.AutoSize = true;
            this.lblResult.Location = new System.Drawing.Point(208, 53);
            this.lblResult.Name = "lblResult";
            this.lblResult.Size = new System.Drawing.Size(0, 13);
            this.lblResult.TabIndex = 39;
            // 
            // button2
            // 
            this.button2.Location = new System.Drawing.Point(214, 28);
            this.button2.Name = "button2";
            this.button2.Size = new System.Drawing.Size(104, 23);
            this.button2.TabIndex = 40;
            this.button2.Text = "Measure Error dB";
            this.button2.UseVisualStyleBackColor = true;
            this.button2.Click += new System.EventHandler(this.button2_Click);
            // 
            // tbarFilePosition
            // 
            this.tbarFilePosition.Enabled = false;
            this.tbarFilePosition.Location = new System.Drawing.Point(88, 53);
            this.tbarFilePosition.Name = "tbarFilePosition";
            this.tbarFilePosition.Size = new System.Drawing.Size(497, 45);
            this.tbarFilePosition.TabIndex = 42;
            this.tbarFilePosition.TickStyle = System.Windows.Forms.TickStyle.TopLeft;
            this.tbarFilePosition.Scroll += new System.EventHandler(this.tbarFilePosition_Scroll);
            this.tbarFilePosition.MouseDown += new System.Windows.Forms.MouseEventHandler(this.tbarFilePosition_MouseDown);
            this.tbarFilePosition.MouseUp += new System.Windows.Forms.MouseEventHandler(this.tbarFilePosition_MouseUp);
            // 
            // tbarVolume
            // 
            this.tbarVolume.LargeChange = 10;
            this.tbarVolume.Location = new System.Drawing.Point(605, 1);
            this.tbarVolume.Maximum = 100;
            this.tbarVolume.Name = "tbarVolume";
            this.tbarVolume.Orientation = System.Windows.Forms.Orientation.Vertical;
            this.tbarVolume.Size = new System.Drawing.Size(45, 94);
            this.tbarVolume.SmallChange = 10;
            this.tbarVolume.TabIndex = 43;
            this.tbarVolume.TickFrequency = 10;
            this.tbarVolume.Value = 100;
            this.tbarVolume.Scroll += new System.EventHandler(this.tbarVolume_Scroll);
            // 
            // button1
            // 
            this.button1.Location = new System.Drawing.Point(104, 28);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(104, 23);
            this.button1.TabIndex = 44;
            this.button1.Text = "Measure Error Bits";
            this.button1.UseVisualStyleBackColor = true;
            this.button1.Click += new System.EventHandler(this.button1_Click);
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1264, 986);
            this.Controls.Add(this.button1);
            this.Controls.Add(this.tbarVolume);
            this.Controls.Add(this.tbarFilePosition);
            this.Controls.Add(this.button2);
            this.Controls.Add(this.lblResult);
            this.Controls.Add(this.chkDrawWaves);
            this.Controls.Add(this.chkDrawFFTs);
            this.Controls.Add(this.picFreqRightTweeter);
            this.Controls.Add(this.picFreqLeftTweeter);
            this.Controls.Add(this.picFreqRightMidrange);
            this.Controls.Add(this.picFreqLeftMidrange);
            this.Controls.Add(this.picFreqRightWoofer);
            this.Controls.Add(this.picFreqLeftWoofer);
            this.Controls.Add(this.picWaveRightTweeter);
            this.Controls.Add(this.picWaveLeftTweeter);
            this.Controls.Add(this.picWaveRightMidrange);
            this.Controls.Add(this.picWaveLeftMidrange);
            this.Controls.Add(this.picWaveRightWoofer);
            this.Controls.Add(this.label11);
            this.Controls.Add(this.label10);
            this.Controls.Add(this.label9);
            this.Controls.Add(this.label8);
            this.Controls.Add(this.label7);
            this.Controls.Add(this.label6);
            this.Controls.Add(this.rdoPlayTweeter);
            this.Controls.Add(this.rdoPlayMidrange);
            this.Controls.Add(this.rdoPlayWoofer);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.picWaveLeftWoofer);
            this.Controls.Add(this.txtUpperTrans);
            this.Controls.Add(this.txtLowerTrans);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.btnOpenFile);
            this.Controls.Add(this.lblFileName);
            this.Controls.Add(this.btnStop);
            this.Controls.Add(this.btnPlay);
            this.Controls.Add(this.txtUpperFreq);
            this.Controls.Add(this.txtLowerFreq);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.label2);
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog;
            this.Name = "Form1";
            this.Text = "Form1";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.Form1_FormClosing);
            ((System.ComponentModel.ISupportInitialize)(this.picWaveLeftWoofer)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveRightWoofer)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveLeftMidrange)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveRightMidrange)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveLeftTweeter)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picWaveRightTweeter)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqLeftWoofer)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqRightWoofer)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqLeftMidrange)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqRightMidrange)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqLeftTweeter)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.picFreqRightTweeter)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.tbarFilePosition)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.tbarVolume)).EndInit();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.TextBox txtLowerFreq;
        private System.Windows.Forms.TextBox txtUpperFreq;
        private System.Windows.Forms.Button btnPlay;
        private System.Windows.Forms.Button btnStop;
        private System.Windows.Forms.Label lblFileName;
        private System.Windows.Forms.Button btnOpenFile;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.TextBox txtLowerTrans;
        private System.Windows.Forms.TextBox txtUpperTrans;
        private System.Windows.Forms.Timer tmrUpdateViz;
        private System.Windows.Forms.PictureBox picWaveLeftWoofer;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.RadioButton rdoPlayWoofer;
        private System.Windows.Forms.RadioButton rdoPlayMidrange;
        private System.Windows.Forms.RadioButton rdoPlayTweeter;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.Label label7;
        private System.Windows.Forms.Label label8;
        private System.Windows.Forms.Label label9;
        private System.Windows.Forms.Label label10;
        private System.Windows.Forms.Label label11;
        private System.Windows.Forms.PictureBox picWaveRightWoofer;
        private System.Windows.Forms.PictureBox picWaveLeftMidrange;
        private System.Windows.Forms.PictureBox picWaveRightMidrange;
        private System.Windows.Forms.PictureBox picWaveLeftTweeter;
        private System.Windows.Forms.PictureBox picWaveRightTweeter;
        private System.Windows.Forms.PictureBox picFreqLeftWoofer;
        private System.Windows.Forms.PictureBox picFreqRightWoofer;
        private System.Windows.Forms.PictureBox picFreqLeftMidrange;
        private System.Windows.Forms.PictureBox picFreqRightMidrange;
        private System.Windows.Forms.PictureBox picFreqLeftTweeter;
        private System.Windows.Forms.PictureBox picFreqRightTweeter;
        private System.Windows.Forms.CheckBox chkDrawFFTs;
        private System.Windows.Forms.CheckBox chkDrawWaves;
        private System.Windows.Forms.Label lblResult;
        private System.Windows.Forms.Button button2;
        private System.Windows.Forms.TrackBar tbarFilePosition;
        private System.Windows.Forms.TrackBar tbarVolume;
        private System.Windows.Forms.Button button1;
    }
}

