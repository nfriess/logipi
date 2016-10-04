namespace AudioPlayer
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
            this.btnStartTest = new System.Windows.Forms.Button();
            this.lblIP = new System.Windows.Forms.Label();
            this.lblWindow = new System.Windows.Forms.Label();
            this.btnStop = new System.Windows.Forms.Button();
            this.btnPlayWav = new System.Windows.Forms.Button();
            this.chkMute = new System.Windows.Forms.CheckBox();
            this.btnStartCountTest = new System.Windows.Forms.Button();
            this.lblSeqDiff = new System.Windows.Forms.Label();
            this.lblQueueLen = new System.Windows.Forms.Label();
            this.btnMuteOn = new System.Windows.Forms.Button();
            this.btnMuteOff = new System.Windows.Forms.Button();
            this.btnPauseOn = new System.Windows.Forms.Button();
            this.btnPauseOff = new System.Windows.Forms.Button();
            this.SuspendLayout();
            // 
            // btnStartTest
            // 
            this.btnStartTest.Location = new System.Drawing.Point(163, 130);
            this.btnStartTest.Name = "btnStartTest";
            this.btnStartTest.Size = new System.Drawing.Size(75, 23);
            this.btnStartTest.TabIndex = 0;
            this.btnStartTest.Text = "Start Test";
            this.btnStartTest.UseVisualStyleBackColor = true;
            this.btnStartTest.Click += new System.EventHandler(this.btnStartTest_Click);
            // 
            // lblIP
            // 
            this.lblIP.AutoSize = true;
            this.lblIP.BackColor = System.Drawing.Color.Red;
            this.lblIP.Location = new System.Drawing.Point(12, 9);
            this.lblIP.Name = "lblIP";
            this.lblIP.Size = new System.Drawing.Size(35, 13);
            this.lblIP.TabIndex = 1;
            this.lblIP.Text = "label1";
            // 
            // lblWindow
            // 
            this.lblWindow.AutoSize = true;
            this.lblWindow.Location = new System.Drawing.Point(12, 35);
            this.lblWindow.Name = "lblWindow";
            this.lblWindow.Size = new System.Drawing.Size(35, 13);
            this.lblWindow.TabIndex = 2;
            this.lblWindow.Text = "label2";
            // 
            // btnStop
            // 
            this.btnStop.Location = new System.Drawing.Point(67, 159);
            this.btnStop.Name = "btnStop";
            this.btnStop.Size = new System.Drawing.Size(75, 23);
            this.btnStop.TabIndex = 3;
            this.btnStop.Text = "Stop";
            this.btnStop.UseVisualStyleBackColor = true;
            this.btnStop.Click += new System.EventHandler(this.btnStop_Click);
            // 
            // btnPlayWav
            // 
            this.btnPlayWav.Location = new System.Drawing.Point(67, 130);
            this.btnPlayWav.Name = "btnPlayWav";
            this.btnPlayWav.Size = new System.Drawing.Size(75, 23);
            this.btnPlayWav.TabIndex = 6;
            this.btnPlayWav.Text = "Play WAV";
            this.btnPlayWav.UseVisualStyleBackColor = true;
            this.btnPlayWav.Click += new System.EventHandler(this.btnPlayWav_Click);
            // 
            // chkMute
            // 
            this.chkMute.AutoSize = true;
            this.chkMute.Checked = true;
            this.chkMute.CheckState = System.Windows.Forms.CheckState.Checked;
            this.chkMute.Enabled = false;
            this.chkMute.Location = new System.Drawing.Point(188, 90);
            this.chkMute.Name = "chkMute";
            this.chkMute.Size = new System.Drawing.Size(50, 17);
            this.chkMute.TabIndex = 7;
            this.chkMute.Text = "Mute";
            this.chkMute.UseVisualStyleBackColor = true;
            // 
            // btnStartCountTest
            // 
            this.btnStartCountTest.Location = new System.Drawing.Point(163, 159);
            this.btnStartCountTest.Name = "btnStartCountTest";
            this.btnStartCountTest.Size = new System.Drawing.Size(75, 23);
            this.btnStartCountTest.TabIndex = 8;
            this.btnStartCountTest.Text = "Count Test";
            this.btnStartCountTest.UseVisualStyleBackColor = true;
            this.btnStartCountTest.Click += new System.EventHandler(this.btnStartCountTest_Click);
            // 
            // lblSeqDiff
            // 
            this.lblSeqDiff.AutoSize = true;
            this.lblSeqDiff.Location = new System.Drawing.Point(12, 60);
            this.lblSeqDiff.Name = "lblSeqDiff";
            this.lblSeqDiff.Size = new System.Drawing.Size(35, 13);
            this.lblSeqDiff.TabIndex = 9;
            this.lblSeqDiff.Text = "label4";
            // 
            // lblQueueLen
            // 
            this.lblQueueLen.AutoSize = true;
            this.lblQueueLen.Location = new System.Drawing.Point(12, 90);
            this.lblQueueLen.Name = "lblQueueLen";
            this.lblQueueLen.Size = new System.Drawing.Size(35, 13);
            this.lblQueueLen.TabIndex = 10;
            this.lblQueueLen.Text = "label1";
            // 
            // btnMuteOn
            // 
            this.btnMuteOn.Location = new System.Drawing.Point(67, 189);
            this.btnMuteOn.Name = "btnMuteOn";
            this.btnMuteOn.Size = new System.Drawing.Size(75, 23);
            this.btnMuteOn.TabIndex = 11;
            this.btnMuteOn.Text = "Mute ON";
            this.btnMuteOn.UseVisualStyleBackColor = true;
            this.btnMuteOn.Click += new System.EventHandler(this.btnMuteOn_Click);
            // 
            // btnMuteOff
            // 
            this.btnMuteOff.Location = new System.Drawing.Point(163, 188);
            this.btnMuteOff.Name = "btnMuteOff";
            this.btnMuteOff.Size = new System.Drawing.Size(75, 23);
            this.btnMuteOff.TabIndex = 12;
            this.btnMuteOff.Text = "Mute OFF";
            this.btnMuteOff.UseVisualStyleBackColor = true;
            this.btnMuteOff.Click += new System.EventHandler(this.btnMuteOff_Click);
            // 
            // btnPauseOn
            // 
            this.btnPauseOn.Location = new System.Drawing.Point(67, 219);
            this.btnPauseOn.Name = "btnPauseOn";
            this.btnPauseOn.Size = new System.Drawing.Size(75, 23);
            this.btnPauseOn.TabIndex = 13;
            this.btnPauseOn.Text = "Pause ON";
            this.btnPauseOn.UseVisualStyleBackColor = true;
            this.btnPauseOn.Click += new System.EventHandler(this.btnPauseOn_Click);
            // 
            // btnPauseOff
            // 
            this.btnPauseOff.Location = new System.Drawing.Point(163, 218);
            this.btnPauseOff.Name = "btnPauseOff";
            this.btnPauseOff.Size = new System.Drawing.Size(75, 23);
            this.btnPauseOff.TabIndex = 14;
            this.btnPauseOff.Text = "Pause OFF";
            this.btnPauseOff.UseVisualStyleBackColor = true;
            this.btnPauseOff.Click += new System.EventHandler(this.btnPauseOff_Click);
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(284, 262);
            this.Controls.Add(this.btnPauseOff);
            this.Controls.Add(this.btnPauseOn);
            this.Controls.Add(this.btnMuteOff);
            this.Controls.Add(this.btnMuteOn);
            this.Controls.Add(this.lblQueueLen);
            this.Controls.Add(this.lblSeqDiff);
            this.Controls.Add(this.btnStartCountTest);
            this.Controls.Add(this.chkMute);
            this.Controls.Add(this.btnPlayWav);
            this.Controls.Add(this.btnStop);
            this.Controls.Add(this.lblWindow);
            this.Controls.Add(this.lblIP);
            this.Controls.Add(this.btnStartTest);
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog;
            this.Name = "Form1";
            this.Text = "Form1";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.Form1_FormClosing);
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.Button btnStartTest;
        private System.Windows.Forms.Label lblIP;
        private System.Windows.Forms.Label lblWindow;
        private System.Windows.Forms.Button btnStop;
        private System.Windows.Forms.Button btnPlayWav;
        private System.Windows.Forms.CheckBox chkMute;
        private System.Windows.Forms.Button btnStartCountTest;
        private System.Windows.Forms.Label lblSeqDiff;
        private System.Windows.Forms.Label lblQueueLen;
        private System.Windows.Forms.Button btnMuteOn;
        private System.Windows.Forms.Button btnMuteOff;
        private System.Windows.Forms.Button btnPauseOn;
        private System.Windows.Forms.Button btnPauseOff;
    }
}

