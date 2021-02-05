classdef TimeIntervalCombined
    %TIMEINTERVALCOMBINED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        timeIntervalList
        Format
    end
    
    methods
        function obj = TimeIntervalCombined(varargin)
            %TIMEINTERVALCOMBINED Construct an instance of this class
            %   Detailed explanation goes here
            timeIntervalList=CellArrayList();
            
            if nargin>0
                el=varargin{1};
                if isstring(el)||ischar(el)
                    try
                    T=readtable(el);
                    obj=TimeIntervalCombined;
                    for iti=1:height(T)
                        tiRow=T(iti,:);
                        theTimeInterval=TimeInterval(tiRow.StartTime,tiRow.SampleRate,tiRow.NumberOfPoints);
                        timeIntervalList.add(theTimeInterval);
                        fprintf('Record addded:');display(theTimeInterval);
                    end
                    catch
                        S=load(el);
                        timeIntervalList=S.obj.timeIntervalList;
                    end
                else
                    for iArgIn=1:nargin
                        theTimeInterval=varargin{iArgIn};
                        assert(isa(theTimeInterval,'TimeInterval'));
                        timeIntervalList.add(theTimeInterval);
                        fprintf('Record addded:');display(theTimeInterval);
                    end
                end
            end
            obj.timeIntervalList=timeIntervalList;
%             obj.Format='dd-MMM-uuuu HH:mm:ss.SSS';
            obj.Format='HH:mm:ss.SSS';
        end
        
        function new_timeIntervalCombined=getTimeIntervalForSamples(obj, times)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            for i=1:size(times,1)
                timeint=times(i,:);
                if timeint(1) <1
                    timeint(1)=1;
                end
                if timeint(2) > obj.getNumberOfPoints
                    timeint(2)=obj.getNumberOfPoints;
                end
                til=obj.timeIntervalList;
                lastSample=0;
                for iInt=1:til.length
                    theTimeInterval=til.get(iInt);
                    upstart=timeint(1)-lastSample;
                    upend=timeint(2)-lastSample;
                    if upend>0
                        newti=theTimeInterval.getTimeIntervalForSamples(upstart,upend);
                        if ~isempty(newti)
                            try
                                new_timeIntervalCombined=new_timeIntervalCombined+newti;
                            catch
                                new_timeIntervalCombined=newti;
                            end
                        end
                    end
                    lastSample=lastSample+theTimeInterval.NumberOfPoints;
                    
                    
                end
            end
        end
        
        
        function timeIntervalCombined=getTimeIntervalForTimes(obj, times)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            times=obj.getDatetime(times);
            times=obj.getSampleFor(times);
            timeIntervalCombined=obj.getTimeIntervalForSamples(times);
        end
        
        function times=getRealTimeFor(obj,samples)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            if numel(samples)>2
                tps=obj.getTimePointsInAbsoluteTimes;
                times=tps(samples);
            else
                for isample=1:numel(samples)
                    sample=samples(isample);
                    newSample=0;
                    til= obj.timeIntervalList;
                    for iInt=1:til.length
                        theTimeInterval=til.get(iInt);
                        lastSample=newSample;
                        newSample=lastSample+theTimeInterval.NumberOfPoints;
                        if sample>lastSample && sample<=newSample
                            time=theTimeInterval.getRealTimeFor(double(sample)-lastSample);
                        end
                    end
                    time.Format=obj.Format;
                    times(isample)=time;
                end
            end
        end
        
        function samples=getSampleFor(obj,times)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            times=obj.getDatetime(times);
            
            samples=nan(size(times));
            til= obj.timeIntervalList;
                lastSample=0;
            for iInt=1:til.length
                theTimeInterval=til.get(iInt);
                idx=times>=theTimeInterval.StartTime&times<=theTimeInterval.getEndTime;
                samples(idx)=theTimeInterval.getSampleFor(times(idx))+lastSample;
                lastSample=lastSample+theTimeInterval.NumberOfPoints;         
            end
%             for itime=1:numel(times)
%                 time=times(itime);
%                 
%                 lastSample=0;
%                 if ~isdatetime(times)
%                     if isduration(time)
%                         time=obj.convertDurationToDatetime(time);
%                     elseif isstring(time{1})||ischar(time{1})
%                         time=obj.convertStringToDatetime(time);
%                     end
%                 end
%                 %                 time.Second=floor(time.Second);
%                 if time<obj.getStartTime
%                     %                     warning('Given time(%s) is earlier then record start(%s).\n',...
%                     %                         time,obj.getStartTime);
%                     time=obj.getStartTime;
%                 elseif time>obj.getEndTime
%                     %                     warning('Given time(%s) is later then record end(%s).\n',...
%                     %                         time,obj.getEndTime);
%                     time=obj.getEndTime;
%                 end
%                 
%                 
%                 til= obj.timeIntervalList;
%                 found=0;
%                 for iInt=1:til.length
%                     if ~found
%                         if time>=theTimeInterval.StartTime
%                             if time<=theTimeInterval.getEndTime
%                                 sample=theTimeInterval.getSampleFor(time)+lastSample;
%                                 found=1;
%                             end
%                         else
%                             sample=1+lastSample;
%                             found=1;
%                         end
%                         
%                         lastSample=lastSample+theTimeInterval.NumberOfPoints;
%                     end
%                 end
%                 samples(itime)=sample;
%             end
        end
        
        function time=getEndTime(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            til= obj.timeIntervalList;
            theTimeInterval=til.get(til.length);
            time=theTimeInterval.getEndTime;
            time.Format=obj.Format;
        end
        
        function obj = plus(obj,varargin)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            for iArgIn=1:nargin-1
                theTimeInterval=varargin{iArgIn};
                if ~isempty(theTimeInterval)
                    try
                        assert(isa(theTimeInterval,'TimeInterval'));
                        obj.timeIntervalList.add(theTimeInterval);
                        fprintf('Record addded:');display(theTimeInterval);
                    catch
                        assert(isa(theTimeInterval,'TimeIntervalCombined'));
                        til=theTimeInterval.timeIntervalList.createIterator;
                        while(til.hasNext)
                            obj.timeIntervalList.add(til.next);
                        end
                    end
                end
            end
        end
        
        function numberOfPoints=getNumberOfPoints(obj)
            til= obj.timeIntervalList;
            numberOfPoints=0;
            for iInt=1:til.length
                theTimeInterval=til.get(iInt);
                numberOfPoints=numberOfPoints+theTimeInterval.NumberOfPoints;
            end
        end
        function sampleRate=getSampleRate(obj)
            til= obj.timeIntervalList;
            for iInt=1:til.length
                theTimeInterval=til.get(iInt);
                if ~exist('sampleRate', 'var')
                    sampleRate=theTimeInterval.SampleRate;
                else
                    assert(sampleRate==theTimeInterval.SampleRate);
                end
            end
        end
        function startTime=getStartTime(obj)
            til= obj.timeIntervalList;
            theTimeInterval=til.get(1);
            startTime=theTimeInterval.getStartTime;
        end
        function [timeIntervalCombined,resArr]=getDownsampled(obj,downsampleFactor)
            til= obj.timeIntervalList;
            resArr=[];
            for iInt=1:til.length
                theTimeInterval=til.get(iInt);
                [ds_ti, residual]=theTimeInterval.getDownsampled(downsampleFactor);
                if iInt==1
                    residuals(iInt,1)=ds_ti.NumberOfPoints*downsampleFactor+1;
                    residuals(iInt,2)=ds_ti.NumberOfPoints*downsampleFactor+residual;
                else
                    numPointsPrev=residuals(iInt-1,2);
                    residuals(iInt,1)=numPointsPrev+ds_ti.NumberOfPoints*downsampleFactor+1;
                    residuals(iInt,2)=numPointsPrev+ds_ti.NumberOfPoints*downsampleFactor+residual;
                end
                resArr=[resArr residuals(iInt,1):residuals(iInt,2)];
                if exist('timeIntervalCombined','var')
                    timeIntervalCombined=timeIntervalCombined+ds_ti;
                else
                    timeIntervalCombined=ds_ti;
                end
                
            end
            
        end
        function tps=getTimePointsInSec(obj)
            til= obj.timeIntervalList;
            st=obj.getStartTime;
            for iInt=1:til.length
                theTimeInterval=til.get(iInt);
                tp=theTimeInterval.getTimePointsInSec+seconds(theTimeInterval.getStartTime-st);
                if exist('tps','var')
                    tps=horzcat(tps, tp);
                else
                    tps=tp;
                end
            end
        end
        function tps=getTimePointsInAbsoluteTimes(obj)
            tps=seconds(obj.getTimePointsInSec)+obj.getStartTime;
        end
        function tps=getTimePointsInSamples(obj)
            tps=1:obj.getNumberOfPoints;
        end
        function arrnew=adjustTimestampsAsIfNotInterrupted(obj,arr)
            arrnew=arr;
            til= obj.timeIntervalList;
            st=obj.getStartTime;
            for iAdj=1:til.length
                theTimeInterval=til.get(iAdj);
                tistart=theTimeInterval.getStartTime;
                
                if iAdj==1
                    sample(iAdj).adj=0;
                    sample(iAdj).begin=1;
                    sample(iAdj).end=theTimeInterval.NumberOfPoints;
                else
                    tiprev=til.get(iAdj-1);
                    adjustinthis=seconds(theTimeInterval.getStartTime-tiprev.getEndTime)*...
                        obj.getSampleRate;
                    sample(iAdj).adj=sample(iAdj-1).adj+adjustinthis;
                    sample(iAdj).begin=sample(iAdj-1).end+1;
                    sample(iAdj).end=sample(iAdj).begin+theTimeInterval.NumberOfPoints;
                end
                idx=(arr>=sample(iAdj).begin)&(arr<=sample(iAdj).end);
                arrnew(idx)=arr(idx) + sample(iAdj).adj;
            end
            %             tps(end)=[];
        end
        function ti=mergeTimeIntervals(obj)
            til= obj.timeIntervalList;
            st=obj.getStartTime;
            
            ti=TimeInterval(obj.getStartTime, obj.getSampleRate, obj.getNumberOfPoints);
            %             tps(end)=[];
        end
        
        function plot(obj)
            til=obj.timeIntervalList;
            iter=til.createIterator;
            while iter.hasNext
                theTimeInterval=iter.next;
                theTimeInterval.plot;hold on;
            end
        end
        function save(obj,folder)
            filename=fullfile(folder,'_added_TimeIntervalCombined.mat');
            save(filename,'obj');
        end
        function ticd=saveTable(obj,filePath)
            iter=obj.timeIntervalList.createIterator;
            count=1;
            
            while(iter.hasNext)
                ti=iter.next;
                S(count).StartTime=ti.StartTime;
                S(count).NumberOfPoints=ti.NumberOfPoints;
                S(count).SampleRate=ti.SampleRate;
                count=count+1;
            end
            T=struct2table(S);
            writetable(T,filePath);
            ticd=TimeIntervalCombined(filePath);
        end
        function ticd=readTimeIntervalTable(obj,table)
            T=readtable(table);
            ticd=TimeIntervalCombined;
            for iti=1:height(T)
                tiRow=T(iti,:);
                ti=TimeInterval(tiRow.StartTime,tiRow.SampleRate,tiRow.NumberOfPoints);
                ticd=ticd+ti;
            end
        end
        
    end
    methods
        function dt=convertDurationToDatetime(obj,time)
            st=obj.getStartTime;
            dt=datetime(st.Year,st.Month,st.Day)+time;
        end
        function dt=convertStringToDatetime(obj,time)
            st=obj.getStartTime;
            dt1=datetime(time,'Format','HH:mm');
            dt=datetime(st.Year,st.Month,st.Day)+hours(dt1.Hour)+minutes(dt1.Minute);
        end
        function times=getDatetime(obj,times)
            if ~isdatetime(times)
                if isduration(times)
                    times=obj.convertDurationToDatetime(times);
                elseif isstring(times{1})||ischar(times{1})
                    times=obj.convertStringToDatetime(times);
                end
            end
        end
        function date=getDate(obj)
            st=obj.getEndTime;
            date=datetime( st.Year,st.Month,st.Day);
        end

        
    end
end
