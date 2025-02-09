-- This script was generated by a beta version of the ERD tool in pgAdmin 4.
-- Please log an issue at https://redmine.postgresql.org/projects/pgadmin4/issues/new if you find any bugs, including reproduction steps.
BEGIN;


CREATE TABLE IF NOT EXISTS public.blog_inbox
(
    inbox_id serial NOT NULL,
    user_id integer NOT NULL,
    message_id integer NOT NULL,
    inbox_message text,
    created_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (inbox_id)
);

CREATE TABLE IF NOT EXISTS public.blog_rollers
(
    role_id serial NOT NULL,
    role_name character varying,
    user_change_active boolean DEFAULT FALSE,
    view_number_of_record boolean DEFAULT FALSE,
    user_delete_account boolean DEFAULT FALSE,
    user_change_role boolean DEFAULT FALSE,
    add_new_role boolean DEFAULT FALSE,
    created_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id),
	UNIQUE(role_name)
);

CREATE TABLE IF NOT EXISTS public.blog_users
(
    user_id serial NOT NULL,
    user_email character varying NOT NULL,
    user_password character varying NOT NULL,
    user_is_active boolean DEFAULT TRUE,
    user_meta_data character varying,
    user_is_deleted boolean DEFAULT FALSE,
    PRIMARY KEY (user_id),
	UNIQUE(user_email)
);

CREATE TABLE IF NOT EXISTS public.login_log_history
(
    log_id serial NOT NULL,
    log_user_id integer NOT NULL,
    log_login_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    log_is_successful boolean,
    log_comment character varying,
    PRIMARY KEY (log_id)
);

CREATE TABLE IF NOT EXISTS public.users_detail
(
    user_id serial NOT NULL,
    user_name character varying,
    user_surname character varying,
    user_phone character varying,
    user_hescode character varying,
    user_role_id integer NOT NULL,
    user_created_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS public.users_of_number_record
(
    record_id serial NOT NULL,
    role_id integer,
    role_count integer,
    PRIMARY KEY (record_id)
);

ALTER TABLE public.blog_inbox
    ADD FOREIGN KEY (message_id)
    REFERENCES public.blog_users (user_id)
    NOT VALID;


ALTER TABLE public.blog_inbox
    ADD FOREIGN KEY (user_id)
    REFERENCES public.blog_users (user_id)
    NOT VALID;


ALTER TABLE public.login_log_history
    ADD FOREIGN KEY (log_user_id)
    REFERENCES public.blog_users (user_id)
    NOT VALID;


ALTER TABLE public.users_detail
    ADD FOREIGN KEY (user_id)
    REFERENCES public.blog_users (user_id)
    NOT VALID;


ALTER TABLE public.users_detail
    ADD FOREIGN KEY (user_role_id)
    REFERENCES public.blog_rollers (role_id)
    NOT VALID;


ALTER TABLE public.users_of_number_record
    ADD FOREIGN KEY (role_id)
    REFERENCES public.blog_rollers (role_id)
    NOT VALID;
---------------------------------------
-- Yeni Role eklendiğinde çalışacak method
CREATE OR REPLACE FUNCTION 	triger_in_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
	BEGIN
		
		INSERT INTO users_of_number_record (role_id) VALUES((SELECT max(role_id) FROM blog_rollers));
		RETURN NEW;
	END;
$$;


-- CREATE TRİGGER
CREATE TRIGGER triger_in_insert
AFTER INSERT --ekleme komutu çalışınca tetiklensin
ON blog_rollers 	-- blog_rollers tablosundaki değişiklik incelensin
FOR EACH ROW
EXECUTE PROCEDURE triger_in_insert();
-- KOMUT SONU
--------------------------------------
-- user Detail e yeni admin ya da user eklendiğinde tetiklenecek triger
CREATE OR REPLACE FUNCTION 	triger_rolesize_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
	DECLARE
		_sum integer:=0;
		i  blog_rollers%rowtype;
	BEGIN		
		FOR i in (SELECT * from blog_rollers as b)
		LOOP
			_sum:=(SELECT COUNT(*) FROM users_detail as det  WHERE det.user_role_id =i.role_id);
			UPDATE users_of_number_record SET role_count=_sum WHERE role_id=i.role_id; 			
		END LOOP;	
		RETURN NEW;
	END;
$$;



-- CREATE TRİGGER
CREATE TRIGGER triger_rolesize_update
AFTER INSERT or UPDATE --ekleme komutu çalışınca tetiklensin
ON users_detail 	-- users_detail tablosundaki değişiklik incelensin
FOR EACH ROW
EXECUTE PROCEDURE triger_rolesize_update();
-- KOMUT SONU

----------------------------------------------
-- 5 Kez hatalı giriş denemesi yapıldığında Hesabı bloke eden triger

CREATE OR REPLACE FUNCTION bad_entry_trigger_in_registry_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
	$$
		DECLARE
			last_log integer:=0;
			last_user integer:=0;
			wrong_login_attempts_total integer:=0;
		BEGIN
			last_log:= (SELECT MAX(log_id) FROM login_log_history);
			last_user:= (SELECT log_user_id FROM login_log_history WHERE log_id=last_log and log_comment='logIn' );
		
			wrong_login_attempts_total:= (SELECT COUNT(*) FROM (SELECT * FROM login_log_history WHERE log_user_id = last_user AND log_comment='LogIn' ORDER BY log_login_date DESC LIMIT 5) as a WHERE a.log_is_successful=false);
			IF wrong_login_attempts_total>=5 THEN 
				UPDATE blog_users SET user_is_active=false WHERE user_id=last_user;
			END IF;
			RETURN NEW;
		END;	
	$$;
	-- CREATE TRİGGER
CREATE TRIGGER bad_entry_trigger_in_registry_history
AFTER INSERT --ekleme komutu çalışınca tetiklensin
ON login_log_history 	-- users_detail tablosundaki değişiklik incelensin
FOR EACH ROW
EXECUTE PROCEDURE bad_entry_trigger_in_registry_history();
-- KOMUT SONU

-- YENİ KAYIT EKLEME PROCEDURE
CREATE OR REPLACE PROCEDURE registerNewAccount(reg_user_email character varying, 
											   reg_user_password character varying, 
											   reg_user_meta_data character varying,
											   reg_user_name character varying, 
											   reg_user_surname character varying, 
											   reg_user_phone character varying, 
											   reg_user_hescode character varying, 
											   reg_user_role_id integer
											  )
LANGUAGE plpgsql
AS
	$$
		DECLARE
			lastUserID integer :=0;
		BEGIN
			RAISE NOTICE 'start';
			INSERT INTO public.blog_users( user_email, user_password ,user_meta_data) 
			VALUES ( reg_user_email, reg_user_password ,reg_user_meta_data);
			RAISE NOTICE '1';
			lastUserID:=(SELECT MAX(user_id) FROM public.blog_users);
			RAISE NOTICE '2 %', lastUserID;
			INSERT INTO public.users_detail(user_id,user_name, user_surname, user_phone, user_hescode, user_role_id) 
			VALUES ( lastUserID,reg_user_name, reg_user_surname, reg_user_phone, reg_user_hescode,reg_user_role_id);
			RAISE NOTICE '3';
		END;
	$$;
-- kayıt ekleme
-- rolee tanımlama
INSERT INTO public.blog_rollers(
	 role_name, user_change_active, view_number_of_record,user_delete_account, user_change_role, add_new_role)
	VALUES ( 'admin', true, true, true, true, true);
INSERT INTO public.blog_rollers(
	role_name, user_change_active, view_number_of_record,user_delete_account, user_change_role, add_new_role)
	VALUES ( 'user', false, false, false, false, false);
-- login giriş bilgileri tanımlama	

call registerNewAccount('admin','91939f99bqand5d7a3c9aa8eaac08ve3','admin','','','','',1);
call registerNewAccount('user','fe8hebdhcgaif48b87dae0ea868c93fe','user','','','','',2);

	
END;