function logmmse_v2(x_path,xfinal_path)

[x,Srate] = audioread(x_path);

% =============== Initialize variables ===============
x=reshape(x,length(x),1);
len=floor(10*Srate/1000); % Frame size in samples
if rem(len,2)==1, len=len+1; end;
PERC=50; % window overlap in percent of frame size
len1=floor(len*PERC/100);
len2=len-len1;


win=hamming(len);  % define window
syn_win = 1./[win(1:len1)+win(len1+1:end)];

% Noise magnitude calculations - assuming that the first 6 frames is
% noise/silence 

nFFT=2^(nextpow2(len));
noise_mean=zeros(nFFT,1);
j=1;
for m=1:6
    noise_mean=noise_mean+abs(fft(win.*x(j:j+len-1),nFFT));
    j=j+len;
end
noise_mu=noise_mean/6;
noise_mu2=noise_mu.^2;

%--- allocate memory and initialize various variables



x_old=zeros(len1,1);
Nframes=floor(length(x)/len2)-floor(len/len2);
% xfinal=zeros(Nframes*len2,1);
xfinal=zeros(length(x),1);


%===============================  Start Processing =======================================================
%
k=1;
aa=0.98;
mu=0.98;
eta=0.15; 

ksi_min=10^(-25/10);
%time1 =0;
for n=1:Nframes
%tic
    insign=win.*x(k:k+len-1);

     spec=fft(insign,nFFT);
    sig=abs(spec); % compute the magnitude
    sig2=sig.^2;

    gammak=min(sig2./noise_mu2,40);  % limit post SNR to avoid overflows
    if n==1
        ksi=aa+(1-aa)*max(gammak-1,0);
    else
        ksi=aa*Xk_prev./noise_mu2 + (1-aa)*max(gammak-1,0);     % a priori SNR
        ksi=max(ksi_min,ksi);  % limit ksi to -25 dB
    end

    log_sigma_k= gammak.* ksi./ (1+ ksi)- log(1+ ksi);    
    vad_decision= sum(log_sigma_k)/ len;    
    if (vad_decision< eta) 
        % noise only frame found
        noise_mu2= mu* noise_mu2+ (1- mu)* sig2;
    end
    % ===end of vad===

    A=ksi./(1+ksi);  % Log-MMSE estimator
    vk=A.*gammak;
    ei_vk=0.5*expint(vk);
    hw=A.*exp(ei_vk);

    sig=sig.*hw;
    Xk_prev=sig.^2;

    xi_w= ifft( hw .* spec,nFFT);
%     xi_w= ifft(spec,nFFT);
    xi_w= real( xi_w);

    xfinal(k:k+ len2-1)= (x_old+ xi_w(1:len1)).*syn_win;
    x_old= xi_w(len1+ 1: len);

    k=k+len2;
%     tempt = toc;
%     time1=time1+tempt;
end
%display(time1/Nframes);
%wavwrite(xfinal,Srate,16,outfile);

audiowrite(xfinal_path,xfinal,Srate);

end
