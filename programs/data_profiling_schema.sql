
CREATE TABLE value_stats
(
  variablename character(200),
  invaliddates character(100),
  maxlength double precision,
  averagelength double precision,
  missingvalues double precision,
  uniquecount double precision,
  frequency double precision,
  percentage double precision,
  tablename character(250)
)
WITH (
  OIDS=FALSE
);


CREATE TABLE sum_stats
(
  variablename character(200),
  missingvalues double precision,
  sum double precision,
  min double precision,
  mean double precision,
  max double precision,
  skewness double precision,
  standarddeviation double precision,
  median double precision,
  mode double precision,
  tablename character(250)
)
WITH (
  OIDS=FALSE
);



CREATE TABLE patt_freq
(
  variablename character(200),
  originalvalue double precision,
  pattern character(200),
  frequency double precision,
  percentage double precision,
  tablename character(250)
)
WITH (
  OIDS=FALSE
);
